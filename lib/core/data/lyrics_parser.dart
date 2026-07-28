import 'dart:convert';

import 'package:romanize/romanize.dart';
import 'package:xml/xml.dart';

import '../models/lyrics.dart';

class LyricsParser {
  const LyricsParser._();

  static Future<void> ensureRomanizationInitialized() =>
      TextRomanizer.ensureInitialized();

  static final RegExp _lineTimestamp = RegExp(
    r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]',
  );
  static final RegExp _wordTimestamp = RegExp(
    r'<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>',
  );
  static final RegExp _metadata = RegExp(
    r'^\[[a-zA-Z]+:.*\]$',
    caseSensitive: false,
  );
  static final RegExp _kugouLine = RegExp(r'^\[(\d+),(\d+)\](.*)$');
  static final RegExp _kugouWord = RegExp(r'<(\d+),(\d+),(\d+)>([^<]*)');
  static final RegExp _translationCredit = RegExp(
    r'^\s*by\s*[:：].+',
    caseSensitive: false,
  );

  static LyricsDocument parse(String raw, {bool fromRemote = false}) {
    final normalized = _sanitize(raw);
    if (_looksLikeTtml(normalized)) {
      final converted = ttmlToEnhancedLrc(normalized);
      return converted == null
          ? LyricsDocument(raw: normalized, fromRemote: fromRemote)
          : parse(converted, fromRemote: fromRemote);
    }
    if (_looksLikeKugou(normalized)) {
      return _parseKugou(normalized, fromRemote: fromRemote);
    }

    final synced = <SyncedLyricLine>[];
    final plain = <String>[];
    var hasSyncMarker = false;

    for (final sourceLine in const LineSplitter().convert(normalized)) {
      final line = _sanitizeLine(sourceLine);
      if (line.isEmpty || _metadata.hasMatch(line)) continue;
      final timestamp = _lineTimestamp.firstMatch(line);
      if (timestamp == null) {
        final visible = _stripWordTimestamps(line).trim();
        if (hasSyncMarker && synced.isNotEmpty) {
          final last = synced.removeLast();
          final merged = last.text.isEmpty ? visible : '${last.text}\n$visible';
          synced.add(
            SyncedLyricLine(
              time: last.time,
              text: merged,
              words: last.words,
              translation: last.translation,
              romanization: last.romanization,
            ),
          );
        } else if (visible.isNotEmpty) {
          plain.add(visible);
        }
        continue;
      }

      hasSyncMarker = true;
      final content = line.replaceAll(_lineTimestamp, '').trimLeft();
      final lineTime = _durationFromMatch(timestamp);
      final words = _parseWords(content, lineTime);
      synced.add(
        SyncedLyricLine(
          time: lineTime,
          text: _stripWordTimestamps(content).trim(),
          words: words,
        ),
      );
    }

    synced.sort((a, b) => a.time.compareTo(b.time));
    final entireLyricsHasKana = _hasKana(normalized);
    final paired = _pairAdjacentTranslations(synced)
        .map(
          (line) => SyncedLyricLine(
            time: line.time,
            text: line.text,
            words: line.words,
            translation: line.translation,
            romanization:
                line.romanization ??
                _romanizeLine(
                  line.text,
                  entireLyricsHasKana: entireLyricsHasKana,
                ),
          ),
        )
        .toList(growable: false);
    if (paired.isEmpty && plain.isNotEmpty) {
      for (var index = 0; index < plain.length; index++) {
        final romanization = _romanizeLine(
          plain[index],
          entireLyricsHasKana: entireLyricsHasKana,
        );
        if (romanization != null) {
          plain[index] = '${plain[index]}\n$romanization';
        }
      }
    }
    if (plain.isEmpty && paired.isNotEmpty) {
      plain.addAll(
        paired
            .map(
              (line) => <String>[
                line.text,
                if (line.romanization?.isNotEmpty == true) line.romanization!,
                if (line.translation?.isNotEmpty == true) line.translation!,
              ].where((part) => part.isNotEmpty).join('\n'),
            )
            .where((line) => line.isNotEmpty),
      );
    }
    return LyricsDocument(
      raw: normalized,
      plain: List.unmodifiable(plain),
      synced: List.unmodifiable(paired),
      fromRemote: fromRemote,
    );
  }

  static String? ttmlToEnhancedLrc(String input) {
    if (!input.contains('<') ||
        RegExp(r'<!DOCTYPE|<!ENTITY', caseSensitive: false).hasMatch(input)) {
      return null;
    }
    try {
      final document = XmlDocument.parse(input.trimLeft());
      final paragraphs = document.descendantElements
          .where((element) => element.name.local.toLowerCase() == 'p')
          .toList(growable: false);
      if (paragraphs.isEmpty || paragraphs.length > 5000) return null;
      final rows = <({Duration time, String row})>[];
      for (final paragraph in paragraphs) {
        var time = _parseTtmlTime(
          paragraph.getAttribute('begin', namespaceUri: '*') ?? '',
        );
        if (time == null) {
          for (final span in paragraph.descendantElements.where(
            (element) => element.name.local.toLowerCase() == 'span',
          )) {
            time = _parseTtmlTime(
              span.getAttribute('begin', namespaceUri: '*') ?? '',
            );
            if (time != null) break;
          }
        }
        if (time == null) continue;
        final body = _normalizeTtmlParagraph(
          paragraph.children.map(_serializeTtmlNode).join(),
        );
        if (body.isEmpty) continue;
        rows.add((time: time, row: '[${_formatTimestamp(time)}]$body'));
      }
      rows.sort((a, b) => a.time.compareTo(b.time));
      return rows.isEmpty ? null : rows.map((entry) => entry.row).join('\n');
    } on XmlParserException {
      return null;
    } on XmlTagException {
      return null;
    }
  }

  static String _serializeTtmlNode(XmlNode node) {
    if (node is XmlText || node is XmlCDATA) {
      return _sanitizeTtmlText(node.value ?? '');
    }
    if (node is! XmlElement) return '';
    final localName = node.name.local.toLowerCase();
    if (localName == 'br') return '\n';
    final content = node.children.map(_serializeTtmlNode).join();
    if (localName != 'span') return content;
    final normalized = _normalizeTtmlInline(content);
    if (normalized.isEmpty) return '';
    final begin = _parseTtmlTime(
      node.getAttribute('begin', namespaceUri: '*') ?? '',
    );
    return begin == null
        ? normalized
        : '<${_formatTimestamp(begin)}>$normalized';
  }

  static String _sanitizeTtmlText(String value) {
    final cleaned = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(
          RegExp(
            r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\u200B\u200E\u200F\u202A-\u202E\u2066-\u2069]',
          ),
          '',
        );
    if (cleaned.trim().isEmpty) {
      return cleaned.contains('\n') || cleaned.contains('\t') ? '' : ' ';
    }
    return cleaned.replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizeTtmlInline(String value) => value
      .replaceAll(RegExp(r' {2,}'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'^\n+|\n+$'), '');

  static String _normalizeTtmlParagraph(String value) => value
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r' {2,}'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n')
      .trim();

  static String sanitizeImported(String raw) => _sanitize(raw);

  static String _sanitize(String raw) {
    var value = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\uFEFF', '')
        .split('\n')
        .map(_sanitizeLine)
        .join('\n')
        .trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1).trim();
    }
    return value;
  }

  static List<SyncedLyricWord> _parseWords(String content, Duration lineTime) {
    final matches = _wordTimestamp.allMatches(content).toList();
    if (matches.isEmpty) return const <SyncedLyricWord>[];
    final words = <SyncedLyricWord>[];
    if (matches.first.start > 0) {
      final leadingRaw = content.substring(0, matches.first.start);
      final leading = leadingRaw.trim();
      if (leading.isNotEmpty) {
        words.add(SyncedLyricWord(time: lineTime, text: leading));
      }
    }
    var pendingBoundary =
        matches.first.start > 0 &&
        RegExp(r'\s$').hasMatch(content.substring(0, matches.first.start));
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final start = match.end;
      final end = index + 1 < matches.length
          ? matches[index + 1].start
          : content.length;
      final sourceText = content.substring(start, end);
      final timedSourceText = sourceText
          .split(RegExp(r'\r\n|\r|\n|\\r|\\n'))
          .first;
      final trimmedLeft = timedSourceText.trimLeft();
      final text = trimmedLeft.trimRight();
      if (text.isEmpty) {
        if (sourceText.contains(RegExp(r'\s'))) pendingBoundary = true;
        continue;
      }
      words.add(
        SyncedLyricWord(
          time: _durationFromMatch(match),
          text: text,
          startsNewWord:
              words.isEmpty ||
              pendingBoundary ||
              timedSourceText.length != trimmedLeft.length,
        ),
      );
      pendingBoundary = RegExp(r'\s$').hasMatch(timedSourceText);
    }
    if (words.isNotEmpty && words.first.time < lineTime) {
      return <SyncedLyricWord>[
        SyncedLyricWord(
          time: lineTime,
          text: words.first.text,
          startsNewWord: words.first.startsNewWord,
        ),
        ...words.skip(1),
      ];
    }
    return words;
  }

  static List<SyncedLyricLine> _pairAdjacentTranslations(
    List<SyncedLyricLine> lines,
  ) {
    final output = <SyncedLyricLine>[];
    var index = 0;
    while (index < lines.length) {
      final original = lines[index];
      final next = index + 1 < lines.length ? lines[index + 1] : null;
      if (next != null &&
          next.time == original.time &&
          original.translation == null &&
          original.text.trim().isNotEmpty &&
          next.text.trim().isNotEmpty) {
        final translations = <String>[next.text];
        var consumed = 2;
        while (index + consumed < lines.length) {
          final trailing = lines[index + consumed];
          if (trailing.time != original.time ||
              !_translationCredit.hasMatch(trailing.text.trim())) {
            break;
          }
          translations.add(trailing.text);
          consumed++;
        }
        output.add(
          SyncedLyricLine(
            time: original.time,
            text: original.text,
            words: original.words,
            translation: translations.join('\n'),
            romanization: original.romanization,
          ),
        );
        index += consumed;
      } else {
        output.add(original);
        index++;
      }
    }
    return output;
  }

  static bool _looksLikeTtml(String value) {
    final trimmed = value.trimLeft();
    return RegExp(
      r'^(?:<\?xml[\s\S]*?\?>\s*)?<tt(?:\s|>)',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  static bool _looksLikeKugou(String value) {
    for (final rawLine in const LineSplitter().convert(value)) {
      final line = rawLine.trim();
      if (line.isEmpty || _metadata.hasMatch(line)) continue;
      final match = _kugouLine.firstMatch(line);
      if (match != null && (int.tryParse(match.group(1) ?? '') ?? 0) > 999) {
        return true;
      }
    }
    return false;
  }

  static LyricsDocument _parseKugou(String raw, {required bool fromRemote}) {
    var offset = 0;
    final offsetMatch = RegExp(
      r'^\[offset:([+-]?\d+)\]$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(raw);
    if (offsetMatch != null) {
      offset = int.tryParse(offsetMatch.group(1) ?? '') ?? 0;
    }
    final synced = <SyncedLyricLine>[];
    for (final rawLine in const LineSplitter().convert(raw)) {
      final line = rawLine.trim();
      if (line.isEmpty || _metadata.hasMatch(line)) continue;
      final header = _kugouLine.firstMatch(line);
      if (header == null) continue;
      final lineStart = (int.tryParse(header.group(1) ?? '') ?? 0) + offset;
      if (lineStart <= 999 && offset == 0) continue;
      final body = header.group(3) ?? '';
      final words = <SyncedLyricWord>[];
      var previousEndsWithSpace = true;
      for (final wordMatch in _kugouWord.allMatches(body)) {
        final wordOffset = int.tryParse(wordMatch.group(1) ?? '') ?? 0;
        final rawText = wordMatch.group(4) ?? '';
        final text = rawText.trim();
        if (text.isEmpty) continue;
        words.add(
          SyncedLyricWord(
            time: Duration(milliseconds: lineStart + wordOffset),
            text: text,
            startsNewWord:
                previousEndsWithSpace || rawText.startsWith(RegExp(r'\s')),
          ),
        );
        previousEndsWithSpace = RegExp(r'\s$').hasMatch(rawText);
      }
      final plainText = body
          .replaceAllMapped(_kugouWord, (match) => match.group(4) ?? '')
          .trim();
      if (plainText.isEmpty && words.isEmpty) continue;
      synced.add(
        SyncedLyricLine(
          time: Duration(milliseconds: lineStart),
          text: plainText,
          words: words,
        ),
      );
    }
    synced.sort((a, b) => a.time.compareTo(b.time));
    final paired = _pairAdjacentTranslations(synced);
    return LyricsDocument(
      raw: raw,
      plain: paired.map((line) => line.text).toList(growable: false),
      synced: paired,
      fromRemote: fromRemote,
    );
  }

  static String _sanitizeLine(String line) => line
      .replaceAll(
        RegExp(
          r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\u200B\u200E\u200F\u202A-\u202E\u2066-\u2069]',
        ),
        '',
      )
      .trim();

  static Duration _durationFromMatch(Match match) {
    final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
    final fraction = match.group(3) ?? '';
    final milliseconds = switch (fraction.length) {
      2 => (int.tryParse(fraction) ?? 0) * 10,
      _ => int.tryParse(fraction) ?? 0,
    };
    return Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }

  static Duration? _parseTtmlTime(String value) {
    final raw = value.trim();
    if (raw.endsWith('s')) {
      final seconds = double.tryParse(raw.substring(0, raw.length - 1));
      return seconds == null
          ? null
          : Duration(milliseconds: (seconds * 1000).round());
    }
    final parts = raw.split(':');
    final seconds = double.tryParse(parts.last);
    if (seconds == null) return null;
    final hours = parts.length == 3 ? int.tryParse(parts[0]) ?? 0 : 0;
    final minutes = parts.length >= 2
        ? int.tryParse(parts[parts.length - 2]) ?? 0
        : 0;
    return Duration(
      hours: hours,
      minutes: minutes,
      milliseconds: (seconds * 1000).round(),
    );
  }

  static String _formatTimestamp(Duration time) {
    final minutes = time.inMinutes;
    final seconds = time.inSeconds.remainder(60);
    final hundredths = time.inMilliseconds.remainder(1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${hundredths.toString().padLeft(2, '0')}';
  }

  static String _stripWordTimestamps(String value) =>
      value.replaceAll(_wordTimestamp, '');

  static final RegExp _kana = RegExp(
    r'[\u3040-\u309F\u30A0-\u30FF\uFF66-\uFF9F]',
  );
  static final RegExp _han = RegExp(r'[\u4E00-\u9FFF]');
  static final RegExp _hangul = RegExp(r'[\uAC00-\uD7A3]');
  static final RegExp _devanagari = RegExp(r'[\u0900-\u097F]');
  static final RegExp _gurmukhi = RegExp(r'[\u0A00-\u0A7F]');
  static final RegExp _cyrillic = RegExp(r'[\u0400-\u04FF]');

  static bool _hasKana(String text) => _kana.hasMatch(text);

  static String? _romanizeLine(
    String text, {
    required bool entireLyricsHasKana,
  }) {
    String? romanized;
    if (_kana.hasMatch(text) || (entireLyricsHasKana && _han.hasMatch(text))) {
      romanized = JapaneseRomanizer().romanize(text);
    } else if (_han.hasMatch(text)) {
      romanized = const ChineseRomanizer(
        toneAnnotation: ToneAnnotation.none,
      ).romanize(text);
    } else if (_hangul.hasMatch(text)) {
      romanized = const HangulRomanizer().romanize(text);
    } else if (_devanagari.hasMatch(text)) {
      romanized = _transliterateWithMap(text, _devanagariRomanization);
    } else if (_gurmukhi.hasMatch(text)) {
      romanized = _romanizeGurmukhi(text);
    } else if (_cyrillic.hasMatch(text)) {
      romanized = const CyrillicRomanizer().romanize(text);
    }
    romanized = romanized?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (romanized == null || romanized.isEmpty) return null;
    return '${romanized[0].toUpperCase()}${romanized.substring(1)}';
  }

  static String _transliterateWithMap(
    String text,
    Map<String, String> replacements,
  ) {
    final output = StringBuffer();
    var index = 0;
    while (index < text.length) {
      var consumed = false;
      if (index + 1 < text.length) {
        final pair = text.substring(index, index + 2);
        final replacement = replacements[pair];
        if (replacement != null) {
          output.write(replacement);
          index += 2;
          consumed = true;
        }
      }
      if (!consumed) {
        final character = text[index];
        output.write(replacements[character] ?? character);
        index++;
      }
    }
    return output.toString();
  }

  static String _romanizeGurmukhi(String text) {
    final output = StringBuffer();
    var index = 0;
    while (index < text.length) {
      if (text.codeUnitAt(index) == 0x0A71) {
        if (index + 1 < text.length) {
          final next = _gurmukhiRomanization[text[index + 1]];
          if (next != null && next.isNotEmpty) output.write(next[0]);
        }
        index++;
        continue;
      }
      var consumed = false;
      if (index + 1 < text.length) {
        final pair = text.substring(index, index + 2);
        final replacement = _gurmukhiRomanization[pair];
        if (replacement != null) {
          output.write(replacement);
          index += 2;
          consumed = true;
        }
      }
      if (!consumed) {
        final character = text[index];
        output.write(_gurmukhiRomanization[character] ?? character);
        index++;
      }
    }
    return output.toString();
  }

  static const Map<String, String> _devanagariRomanization = {
    'अ': 'a',
    'आ': 'aa',
    'इ': 'i',
    'ई': 'ee',
    'उ': 'u',
    'ऊ': 'oo',
    'ऋ': 'ri',
    'ए': 'e',
    'ऐ': 'ai',
    'ओ': 'o',
    'औ': 'au',
    'क': 'k',
    'ख': 'kh',
    'ग': 'g',
    'घ': 'gh',
    'ङ': 'ng',
    'च': 'ch',
    'छ': 'chh',
    'ज': 'j',
    'झ': 'jh',
    'ञ': 'ny',
    'ट': 't',
    'ठ': 'th',
    'ड': 'd',
    'ढ': 'dh',
    'ण': 'n',
    'त': 't',
    'थ': 'th',
    'द': 'd',
    'ध': 'dh',
    'न': 'n',
    'प': 'p',
    'फ': 'ph',
    'ब': 'b',
    'भ': 'bh',
    'म': 'm',
    'य': 'y',
    'र': 'r',
    'ल': 'l',
    'व': 'v',
    'श': 'sh',
    'ष': 'sh',
    'स': 's',
    'ह': 'h',
    'क्ष': 'ksh',
    'त्र': 'tr',
    'ज्ञ': 'gy',
    'श्र': 'shr',
    'ा': 'aa',
    'ि': 'i',
    'ी': 'ee',
    'ु': 'u',
    'ू': 'oo',
    'ृ': 'ri',
    'े': 'e',
    'ै': 'ai',
    'ो': 'o',
    'ौ': 'au',
    'ं': 'n',
    'ः': 'h',
    'ँ': 'n',
    '़': '',
    '्': '',
    '०': '0',
    '१': '1',
    '२': '2',
    '३': '3',
    '४': '4',
    '५': '5',
    '६': '6',
    '७': '7',
    '८': '8',
    '९': '9',
    'ॐ': 'Om',
    'ऽ': '',
    'क़': 'q',
    'ख़': 'kh',
    'ग़': 'g',
    'ज़': 'z',
    'ड़': 'r',
    'ढ़': 'rh',
    'फ़': 'f',
    'य़': 'y',
  };

  static const Map<String, String> _gurmukhiRomanization = {
    'ੳ': 'o',
    'ਅ': 'a',
    'ੲ': 'e',
    'ਸ': 's',
    'ਹ': 'h',
    'ਕ': 'k',
    'ਖ': 'kh',
    'ਗ': 'g',
    'ਘ': 'gh',
    'ਙ': 'ng',
    'ਚ': 'ch',
    'ਛ': 'chh',
    'ਜ': 'j',
    'ਝ': 'jh',
    'ਞ': 'ny',
    'ਟ': 't',
    'ਠ': 'th',
    'ਡ': 'd',
    'ਢ': 'dh',
    'ਣ': 'n',
    'ਤ': 't',
    'ਥ': 'th',
    'ਦ': 'd',
    'ਧ': 'dh',
    'ਨ': 'n',
    'ਪ': 'p',
    'ਫ': 'ph',
    'ਬ': 'b',
    'ਭ': 'bh',
    'ਮ': 'm',
    'ਯ': 'y',
    'ਰ': 'r',
    'ਲ': 'l',
    'ਵ': 'v',
    'ੜ': 'r',
    'ਸ਼': 'sh',
    'ਖ਼': 'kh',
    'ਗ਼': 'g',
    'ਜ਼': 'z',
    'ਫ਼': 'f',
    'ਲ਼': 'l',
    'ਾ': 'aa',
    'ਿ': 'i',
    'ੀ': 'ee',
    'ੁ': 'u',
    'ੂ': 'oo',
    'ੇ': 'e',
    'ੈ': 'ai',
    'ੋ': 'o',
    'ੌ': 'au',
    'ੰ': 'n',
    'ਂ': 'n',
    'ੱ': '',
    '੍': '',
    '਼': '',
    'ੴ': 'Ek Onkar',
    '੦': '0',
    '੧': '1',
    '੨': '2',
    '੩': '3',
    '੪': '4',
    '੫': '5',
    '੬': '6',
    '੭': '7',
    '੮': '8',
    '੯': '9',
  };
}
