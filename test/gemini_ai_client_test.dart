import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/data/ai/gemini_ai_client.dart';
import 'package:pixelplayer_flutter/core/data/ai/lyrics_ai_translator.dart';
import 'package:pixelplayer_flutter/core/data/lyrics_parser.dart';
import 'package:pixelplayer_flutter/core/models/song.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Gemini response joins all text parts', () {
    const client = GeminiAiClient();
    final text = client.decodeGeneratedText('''
{
  "candidates": [{
    "content": {
      "parts": [{"text": "first "}, {"text": "second"}]
    },
    "finishReason": "STOP"
  }]
}
''');
    expect(text, 'first second');
  });

  test('Gemini blocked response becomes a safe error', () {
    const client = GeminiAiClient();
    expect(
      () => client.decodeGeneratedText(
        '{"promptFeedback":{"blockReason":"SAFETY"}}',
      ),
      throwsA(
        isA<GeminiApiException>().having(
          (error) => error.message,
          'message',
          contains('SAFETY'),
        ),
      ),
    );
  });

  test(
    'AI lyrics translation preserves original timing and word data',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final source = LyricsParser.parse('''
[00:01.00]<00:01.00>Hello <00:01.40>world
[00:05.00]Good night
''');
      final song = Song(
        id: 'translation-test',
        title: 'Hello',
        artist: 'Artist',
        album: 'Album',
        genre: 'Pop',
        duration: const Duration(minutes: 1),
        colors: const [],
      );
      final translated =
          await LyricsAiTranslator(client: const _FakeGeminiClient()).translate(
            song: song,
            lyrics: source,
            targetLanguage: 'vi',
            apiKey: 'test-key',
          );

      expect(translated.synced, hasLength(2));
      expect(translated.synced.first.text, 'Hello world');
      expect(translated.synced.first.translation, 'Xin chào thế giới');
      expect(translated.synced.first.words, isNotEmpty);
      expect(translated.synced.last.translation, 'Chúc ngủ ngon');
    },
  );
}

class _FakeGeminiClient extends GeminiAiClient {
  const _FakeGeminiClient();

  @override
  Future<String> generateContent({
    required String apiKey,
    required String prompt,
    String model = GeminiAiClient.defaultModel,
    String systemPrompt = '',
    double temperature = .7,
    double topP = .95,
    int topK = 64,
    int maxOutputTokens = 8192,
  }) async {
    expect(prompt, contains('Translate song lyrics into vi'));
    return '''
[00:01.00]Hello world
[00:01.00]Xin chào thế giới
[00:05.00]Good night
[00:05.00]Chúc ngủ ngon
''';
  }
}
