import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../app_info.dart';

class GeminiAiClient {
  const GeminiAiClient();

  static const defaultModel = 'gemini-3.1-flash-lite';
  static const defaultModels = <String>[
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash',
    'gemini-3.1-pro-preview',
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
  ];
  static const _host = 'generativelanguage.googleapis.com';
  static const _apiRoot = '/v1beta';
  static const _maximumResponseBytes = 2 * 1024 * 1024;

  Future<String> generateContent({
    required String apiKey,
    required String prompt,
    String model = defaultModel,
    String systemPrompt = '',
    double temperature = .7,
    double topP = .95,
    int topK = 64,
    int maxOutputTokens = 8192,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw const GeminiApiException('Gemini API key is not configured.');
    }
    final cleanModel = _normalizeModel(model);
    final uri = Uri.https(
      _host,
      '$_apiRoot/models/${Uri.encodeComponent(cleanModel)}:generateContent',
    );
    final body = <String, Object>{
      'contents': <Object>[
        <String, Object>{
          'role': 'user',
          'parts': <Object>[
            <String, String>{'text': prompt},
          ],
        },
      ],
      if (systemPrompt.trim().isNotEmpty)
        'system_instruction': <String, Object>{
          'parts': <Object>[
            <String, String>{'text': systemPrompt.trim()},
          ],
        },
      'generationConfig': <String, Object>{
        'temperature': temperature,
        'topP': topP,
        'topK': topK,
        'maxOutputTokens': maxOutputTokens,
      },
    };

    final response = await _request(
      uri,
      apiKey: cleanKey,
      method: 'POST',
      body: jsonEncode(body),
    );
    return decodeGeneratedText(response);
  }

  Future<List<String>> listModels(String apiKey) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw const GeminiApiException('Gemini API key is not configured.');
    }
    final body = await _request(
      Uri.https(_host, '$_apiRoot/models', const {'pageSize': '1000'}),
      apiKey: cleanKey,
    );
    final decoded = jsonDecode(body);
    if (decoded is! Map) return defaultModels;
    final models = decoded['models'];
    if (models is! List) return defaultModels;
    final names = <String>[];
    for (final entry in models) {
      if (entry is! Map) continue;
      final methods = entry['supportedGenerationMethods'];
      if (methods is List &&
          !methods.any((method) => method.toString() == 'generateContent')) {
        continue;
      }
      final name = entry['name']?.toString().replaceFirst('models/', '') ?? '';
      if ((name.startsWith('gemini') || name.startsWith('gemma')) &&
          !_isNonChatModel(name)) {
        names.add(name);
      }
    }
    return <String>{...names, ...defaultModels}.toList()..sort();
  }

  Future<bool> validateApiKey(String apiKey) async {
    try {
      await listModels(apiKey);
      return true;
    } on GeminiApiException {
      return false;
    }
  }

  @visibleForTesting
  String decodeGeneratedText(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const GeminiApiException('Gemini returned an invalid response.');
    }
    final feedback = decoded['promptFeedback'];
    if (feedback is Map) {
      final reason = feedback['blockReason']?.toString();
      if (reason != null && reason.isNotEmpty) {
        throw GeminiApiException('Gemini blocked the request ($reason).');
      }
    }
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const GeminiApiException('Gemini returned an empty response.');
    }
    final candidate = candidates.first;
    if (candidate is! Map) {
      throw const GeminiApiException('Gemini returned an invalid response.');
    }
    final content = candidate['content'];
    if (content is! Map || content['parts'] is! List) {
      final finishReason = candidate['finishReason']?.toString();
      throw GeminiApiException(
        finishReason == null
            ? 'Gemini returned an empty response.'
            : 'Gemini stopped without text ($finishReason).',
      );
    }
    final text = (content['parts'] as List)
        .whereType<Map>()
        .map((part) => part['text']?.toString() ?? '')
        .join()
        .trim();
    if (text.isEmpty) {
      throw const GeminiApiException('Gemini returned an empty response.');
    }
    return text;
  }

  Future<String> _request(
    Uri uri, {
    required String apiKey,
    String method = 'GET',
    String? body,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = method == 'POST'
          ? await client.postUrl(uri)
          : await client.getUrl(uri);
      request.headers
        ..set('x-goog-api-key', apiKey)
        ..set(HttpHeaders.acceptHeader, ContentType.json.mimeType)
        ..set(HttpHeaders.userAgentHeader, AppInfo.userAgent);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(body);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 65),
      );
      final responseBody = await _readLimited(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GeminiApiException(
          _errorMessage(response.statusCode, responseBody),
          statusCode: response.statusCode,
        );
      }
      return responseBody;
    } on GeminiApiException {
      rethrow;
    } on TimeoutException {
      throw const GeminiApiException('Gemini request timed out.');
    } on SocketException {
      throw const GeminiApiException(
        'Could not connect to Gemini. Check your internet connection.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _readLimited(HttpClientResponse response) async {
    final output = BytesBuilder(copy: false);
    var length = 0;
    await for (final bytes in response) {
      length += bytes.length;
      if (length > _maximumResponseBytes) {
        throw const GeminiApiException('Gemini response was too large.');
      }
      output.add(bytes);
    }
    return utf8.decode(output.takeBytes(), allowMalformed: false);
  }

  String _errorMessage(int statusCode, String body) {
    String? providerMessage;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        providerMessage = (decoded['error'] as Map)['message']?.toString();
      }
    } catch (_) {
      // Return the status-specific safe fallback below.
    }
    return switch (statusCode) {
      400 => providerMessage ?? 'Gemini rejected the request.',
      401 || 403 => 'Gemini API key is invalid or lacks access.',
      404 => 'The selected Gemini model is unavailable.',
      429 => 'Gemini rate limit reached. Try again shortly.',
      >= 500 => 'Gemini is temporarily unavailable.',
      _ => providerMessage ?? 'Gemini request failed ($statusCode).',
    };
  }

  String _normalizeModel(String model) {
    final value = model.trim().replaceFirst('models/', '');
    return value.isEmpty ? defaultModel : value;
  }

  bool _isNonChatModel(String name) {
    final lower = name.toLowerCase();
    return const [
      'embedding',
      'aqa',
      'imagen',
      'veo',
      'tts',
      'robotics',
      'computer-use',
    ].any(lower.contains);
  }
}

class GeminiApiException implements Exception {
  const GeminiApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
