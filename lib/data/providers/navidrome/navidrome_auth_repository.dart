import 'dart:convert';
import 'dart:io';

class NavidromeAuthRepository {
  const NavidromeAuthRepository();

  Future<String> validate({
    required Uri server,
    required String username,
    required String password,
  }) async {
    final uri = server
        .resolve('/rest/ping.view')
        .replace(
          queryParameters: {
            'u': username,
            'p': password,
            'v': '1.16.1',
            'c': 'PixelPlay',
            'f': 'json',
          },
        );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final response = await (await client.getUrl(uri)).close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Server returned ${response.statusCode}');
      }
      final decoded = Map<String, dynamic>.from(jsonDecode(body) as Map);
      final subsonic = decoded['subsonic-response'] as Map?;
      if (subsonic?['status'] != 'ok') {
        throw Exception('Navidrome rejected these credentials');
      }
      return '$username @ ${server.host}';
    } finally {
      client.close(force: true);
    }
  }
}
