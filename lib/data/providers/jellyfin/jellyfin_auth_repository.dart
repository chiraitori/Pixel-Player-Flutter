import 'dart:convert';
import 'dart:io';

import '../../../core/app_info.dart';

class JellyfinAuthRepository {
  const JellyfinAuthRepository();

  Future<String> validate({
    required Uri server,
    required String username,
    required String password,
  }) async {
    final uri = server.resolve('/Users/AuthenticateByName');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.postUrl(uri);
      request.headers
        ..contentType = ContentType.json
        ..set(
          'X-Emby-Authorization',
          'MediaBrowser Client="PixelPlay", Device="Flutter", '
              'DeviceId="pixelplay-flutter", Version="${AppInfo.version}"',
        );
      request.write(jsonEncode({'Username': username, 'Pw': password}));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Jellyfin rejected these credentials');
      }
      final decoded = Map<String, dynamic>.from(jsonDecode(body) as Map);
      final user = decoded['User'] as Map?;
      return '${user?['Name'] ?? username} @ ${server.host}';
    } finally {
      client.close(force: true);
    }
  }
}
