import '../../models/lyrics.dart';
import '../../models/song.dart';
import '../lyrics_parser.dart';
import '../lyrics_service.dart';
import 'gemini_ai_client.dart';

class LyricsAiTranslator {
  const LyricsAiTranslator({this.client = const GeminiAiClient()});

  final GeminiAiClient client;

  Future<LyricsDocument> translate({
    required Song song,
    required LyricsDocument lyrics,
    required String targetLanguage,
    required String apiKey,
    String model = GeminiAiClient.defaultModel,
  }) async {
    if (!lyrics.hasSynced) {
      throw const LyricsTranslationException(
        'Synced lyrics are required for AI translation.',
      );
    }
    if (lyrics.synced.any(
      (line) => line.translation?.trim().isNotEmpty == true,
    )) {
      throw const LyricsTranslationException(
        'These lyrics already contain a translation.',
      );
    }

    final rawLyrics = _toLrc(
      lyrics.synced,
      includeTranslations: false,
      includeWordTimings: false,
    );
    final response = await client.generateContent(
      apiKey: apiKey,
      model: model,
      temperature: .1,
      maxOutputTokens: 8192,
      prompt: _translationPrompt(
        rawLyrics,
        targetLanguage.trim().isEmpty ? 'English' : targetLanguage.trim(),
      ),
    );
    final cleaned = _stripCodeFence(response);
    if (cleaned.trim() == 'ALREADY_IN_TARGET_LANGUAGE') {
      throw const LyricsAlreadyInTargetLanguageException();
    }
    if (cleaned.length > 50000) {
      throw const LyricsTranslationException(
        'The translated lyrics were too large.',
      );
    }
    final parsed = LyricsParser.parse(cleaned);
    if (!parsed.hasSynced) {
      throw const LyricsTranslationException(
        'Gemini returned lyrics without valid timestamps.',
      );
    }

    final translatedByTime = <int, List<String>>{};
    for (final line in parsed.synced) {
      final translation = line.translation?.trim();
      if (translation == null || translation.isEmpty) continue;
      translatedByTime
          .putIfAbsent(line.time.inMilliseconds, () => <String>[])
          .add(translation);
    }
    final merged = <SyncedLyricLine>[];
    for (final original in lyrics.synced) {
      final translations =
          translatedByTime[original.time.inMilliseconds] ?? const <String>[];
      merged.add(
        SyncedLyricLine(
          time: original.time,
          text: original.text,
          words: original.words,
          romanization: original.romanization,
          translation: translations.isEmpty ? null : translations.join('\n'),
        ),
      );
    }
    if (!merged.any((line) => line.translation?.isNotEmpty == true)) {
      throw const LyricsTranslationException(
        'Gemini did not return a usable translation.',
      );
    }

    final raw = _toLrc(
      merged,
      includeTranslations: true,
      includeWordTimings: true,
    );
    final document = LyricsParser.parse(raw);
    await LyricsService.instance.saveLyrics(song, document);
    return document;
  }

  String _translationPrompt(String lyrics, String language) =>
      '''
<task>Translate song lyrics into $language.</task>

<rules>
- Preserve ALL timestamps [mm:ss.xx] exactly — never modify, merge, or drop them.
- Output TWO lines per original line: the original, then the translation with the same timestamp.
- NEVER add explanations, labels, numbering, section headers, or formatting.
- NEVER remove, merge, split, or reorder lines.
- If lyrics are ALREADY mostly in $language, output ONLY: ALREADY_IN_TARGET_LANGUAGE
</rules>

<format>
[original timestamp] original text
[same timestamp] translated text
</format>

<lyrics>
$lyrics
</lyrics>''';

  String _toLrc(
    List<SyncedLyricLine> lines, {
    required bool includeTranslations,
    required bool includeWordTimings,
  }) {
    final output = StringBuffer();
    for (final line in lines) {
      final timestamp = _timestamp(line.time);
      final text = !includeWordTimings || line.words.isEmpty
          ? line.text
          : _enhancedLineText(line.words);
      output.writeln('[$timestamp]$text');
      if (includeTranslations && line.translation?.trim().isNotEmpty == true) {
        for (final translation in line.translation!.trim().split('\n')) {
          output.writeln('[$timestamp]$translation');
        }
      }
    }
    return output.toString().trim();
  }

  String _enhancedLineText(List<SyncedLyricWord> words) {
    final output = StringBuffer();
    for (var index = 0; index < words.length; index++) {
      final word = words[index];
      if (index > 0 && word.startsNewWord) output.write(' ');
      output.write('<${_timestamp(word.time)}>${word.text}');
    }
    return output.toString();
  }

  String _timestamp(Duration duration) {
    final totalHundredths = duration.inMilliseconds ~/ 10;
    final minutes = totalHundredths ~/ 6000;
    final seconds = (totalHundredths ~/ 100).remainder(60);
    final hundredths = totalHundredths.remainder(100);
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${hundredths.toString().padLeft(2, '0')}';
  }

  String _stripCodeFence(String input) {
    final trimmed = input.trim();
    if (!trimmed.startsWith('```')) return trimmed;
    return trimmed
        .replaceFirst(RegExp(r'^```(?:lrc|text)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
  }
}

class LyricsTranslationException implements Exception {
  const LyricsTranslationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LyricsAlreadyInTargetLanguageException
    extends LyricsTranslationException {
  const LyricsAlreadyInTargetLanguageException()
    : super('Lyrics are already in the target language.');
}
