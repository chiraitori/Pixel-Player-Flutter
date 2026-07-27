import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/data/lyrics_parser.dart';

void main() {
  test('parses LRC timestamps, word timing, and paired translation', () {
    final lyrics = LyricsParser.parse('''
[ar:PixelPlayer]
[00:01.20]<00:01.20>Hello <00:01.70>world
[00:01.20]Xin chào thế giới
[00:03.50]Next line
''');

    expect(lyrics.hasSynced, isTrue);
    expect(lyrics.synced, hasLength(2));
    expect(lyrics.synced.first.time.inMilliseconds, 1200);
    expect(lyrics.synced.first.text, 'Hello world');
    expect(lyrics.synced.first.words, hasLength(2));
    expect(lyrics.synced.first.words.last.time.inMilliseconds, 1700);
    expect(lyrics.synced.first.translation, 'Xin chào thế giới');
  });

  test('keeps plain lyrics available for Static mode', () {
    final lyrics = LyricsParser.parse('First line\n\nSecond line');

    expect(lyrics.hasSynced, isFalse);
    expect(lyrics.plain, ['First line', 'Second line']);
  });

  test('converts basic TTML paragraphs into synced LRC', () {
    final lrc = LyricsParser.ttmlToEnhancedLrc('''
<tt><body><div>
  <p begin="00:00:02.500" end="00:00:04.000">A &amp; B</p>
</div></body></tt>
''');
    final lyrics = LyricsParser.parse(lrc!);

    expect(lyrics.synced.single.time.inMilliseconds, 2500);
    expect(lyrics.synced.single.text, 'A & B');
  });

  test('strips BOM, bidi format controls, and document quotes', () {
    final lyrics = LyricsParser.parse(
      '"\uFEFF\u202A[00:03.80\u202C]Time is standing still\n'
      '[00:09.86]Tracing my body"',
    );

    expect(lyrics.synced, hasLength(2));
    expect(lyrics.synced.first.time.inMilliseconds, 3800);
    expect(lyrics.synced.first.text, 'Time is standing still');
  });

  test('keeps untimed continuation text on the previous synced line', () {
    final lyrics = LyricsParser.parse(
      '[00:01.00]First half\nsecond half\n[00:03.00]Next line',
    );

    expect(lyrics.synced, hasLength(2));
    expect(lyrics.synced.first.text, 'First half\nsecond half');
  });

  test('parses Kugou relative word timing', () {
    final lyrics = LyricsParser.parse(
      '[offset:100]\n'
      '[2000,1500]<0,500,0>Hello <500,500,0>world',
    );

    expect(lyrics.synced, hasLength(1));
    expect(lyrics.synced.single.time.inMilliseconds, 2100);
    expect(lyrics.synced.single.text, 'Hello world');
    expect(lyrics.synced.single.words, hasLength(2));
    expect(lyrics.synced.single.words.last.time.inMilliseconds, 2600);
  });

  test('preserves Apple TTML word-by-word timestamps', () {
    final converted = LyricsParser.ttmlToEnhancedLrc('''
      <?xml version="1.0" encoding="utf-8"?>
      <tt xmlns="http://www.w3.org/ns/ttml">
        <body><div>
          <p begin="7.531" end="12.005">
            <span begin="7.531" end="7.782">Yeah, </span>
            <span begin="9.208" end="9.443">I </span>
            <span begin="9.443" end="9.675">bet</span>
          </p>
        </div></body>
      </tt>
    ''');
    final lyrics = LyricsParser.parse(converted!);

    expect(lyrics.synced, hasLength(1));
    expect(lyrics.synced.single.text, 'Yeah, I bet');
    expect(lyrics.synced.single.words, hasLength(3));
    expect(lyrics.synced.single.words[1].time.inMilliseconds, 9200);
  });

  test('strips extra line timestamps instead of duplicating the line', () {
    final lyrics = LyricsParser.parse('''
[00:12.57]Sinking under
[00:26.42][01:12.34]Three in the morning
[00:41.71][00:52.96][01:27.42]My heart keeps breaking
''');

    expect(lyrics.synced, hasLength(3));
    expect(lyrics.synced.map((line) => line.text), [
      'Sinking under',
      'Three in the morning',
      'My heart keeps breaking',
    ]);
    expect(lyrics.synced.map((line) => line.time.inMilliseconds), [
      12570,
      26420,
      41710,
    ]);
  });

  test('does not time an untagged inline translation as the final word', () {
    final lyrics = LyricsParser.parse(
      r'[00:10.00]<00:10.00>To <00:10.30>fall <00:10.60>in '
      r'<00:10.90>love\n怦然心动',
    );

    expect(lyrics.synced.single.text, r'To fall in love\n怦然心动');
    expect(lyrics.synced.single.words.map((word) => word.text), [
      'To',
      'fall',
      'in',
      'love',
    ]);
  });

  test('standalone timed whitespace starts the next visual word', () {
    final lyrics = LyricsParser.parse(
      '[00:10.00]<00:10.00>To<00:10.20> <00:10.40>fall',
    );

    expect(lyrics.synced.single.text, 'To fall');
    expect(lyrics.synced.single.words.map((word) => word.startsNewWord), [
      true,
      true,
    ]);
  });

  test(
    'TTML falls back to the first span time and preserves inter-span spaces',
    () {
      final converted = LyricsParser.ttmlToEnhancedLrc('''
<?xml version="1.0"?>
<tt xmlns="http://www.w3.org/ns/ttml"><body><div>
  <p><span begin="7.531">Yeah,</span> <span begin="9.208">I</span> <span begin="9.443">bet</span></p>
</div></body></tt>
''');
      final lyrics = LyricsParser.parse(converted!);

      expect(lyrics.synced.single.time.inMilliseconds, 7530);
      expect(lyrics.synced.single.text, 'Yeah, I bet');
      expect(lyrics.synced.single.words.map((word) => word.text), [
        'Yeah,',
        'I',
        'bet',
      ]);
    },
  );

  test('rejects TTML documents containing a doctype', () {
    final converted = LyricsParser.ttmlToEnhancedLrc('''
      <!DOCTYPE tt [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
      <tt><body><p begin="1.0">&xxe;</p></body></tt>
    ''');

    expect(converted, isNull);
  });

  test('generates Japanese romanization and keeps it in the plain view', () {
    final lyrics = LyricsParser.parse('[00:01.00]こんにちは');

    expect(lyrics.synced.single.romanization, 'Konnichiha');
    expect(lyrics.plain.single, 'こんにちは\nKonnichiha');
  });

  test('uses Chinese pinyin without tone marks like the Kotlin parser', () {
    final lyrics = LyricsParser.parse('[00:01.00]你好世界');

    expect(lyrics.synced.single.romanization, 'Ni hao shi jie');
  });

  test('generates Korean, Hindi, Punjabi and Cyrillic romanizations', () {
    expect(
      LyricsParser.parse('[00:01.00]안녕하세요').synced.single.romanization,
      'Annyeonghaseyo',
    );
    expect(
      LyricsParser.parse('[00:01.00]नमस्ते').synced.single.romanization,
      'Nmste',
    );
    expect(
      LyricsParser.parse('[00:01.00]ਸਤ ਸ੍ਰੀ ਅਕਾਲ').synced.single.romanization,
      'St sree akaal',
    );
    expect(
      LyricsParser.parse('[00:01.00]Привет мир').synced.single.romanization,
      'Privet mir',
    );
  });
}
