import 'dart:convert';
import 'dart:io';

/// Stateless Subsonic/OpenSubsonic client used by Navidrome dashboards.
///
/// Credentials stay in AppController settings; this object only builds requests
/// and converts the server's JSON responses into strongly typed dashboard data.
class NavidromeApiService {
  const NavidromeApiService({
    required this.server,
    required this.username,
    required this.password,
  });

  final Uri server;
  final String username;
  final String password;

  Future<List<NavidromePlaylist>> getPlaylists() async {
    final response = await _get('getPlaylists.view');
    final playlists = _response(response)['playlists'] as Map?;
    final raw = playlists?['playlist'];
    final values = raw is List
        ? raw
        : raw == null
        ? const []
        : [raw];
    return values
        .whereType<Map>()
        .map(
          (value) =>
              NavidromePlaylist.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false);
  }

  Future<List<NavidromeTrack>> getPlaylistTracks(String playlistId) async {
    final response = await _get('getPlaylist.view', {'id': playlistId});
    final playlist = _response(response)['playlist'] as Map?;
    final raw = playlist?['entry'];
    final values = raw is List
        ? raw
        : raw == null
        ? const []
        : [raw];
    return values
        .whereType<Map>()
        .map(
          (value) => NavidromeTrack.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false);
  }

  Uri streamUri(String id) => _uri('stream.view', {'id': id});

  Uri coverArtUri(String id, {int size = 500}) =>
      _uri('getCoverArt.view', {'id': id, 'size': '$size'});

  Future<Map<String, dynamic>> _get(
    String endpoint, [
    Map<String, String> parameters = const {},
  ]) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(_uri(endpoint, parameters));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Navidrome returned ${response.statusCode}');
      }
      final decoded = Map<String, dynamic>.from(jsonDecode(body) as Map);
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _response(Map<String, dynamic> payload) {
    final response = Map<String, dynamic>.from(
      payload['subsonic-response'] as Map? ?? const {},
    );
    if (response['status'] != 'ok') {
      final error = response['error'] as Map?;
      throw StateError(
        error?['message']?.toString() ?? 'Navidrome request failed',
      );
    }
    return response;
  }

  Uri _uri(String endpoint, [Map<String, String> parameters = const {}]) {
    final root = server.path.endsWith('/') ? server.path : '${server.path}/';
    return server.replace(
      path: '${root}rest/$endpoint'.replaceFirst('//rest', '/rest'),
      queryParameters: {
        'u': username,
        'p': password,
        'v': '1.16.1',
        'c': 'PixelPlay',
        'f': 'json',
        ...parameters,
      },
    );
  }
}

class NavidromePlaylist {
  const NavidromePlaylist({
    required this.id,
    required this.name,
    required this.songCount,
    this.coverArtId,
  });

  factory NavidromePlaylist.fromJson(Map<String, dynamic> json) =>
      NavidromePlaylist(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Untitled playlist',
        songCount: (json['songCount'] as num?)?.toInt() ?? 0,
        coverArtId: json['coverArt']?.toString(),
      );

  final String id;
  final String name;
  final int songCount;
  final String? coverArtId;
}

class NavidromeTrack {
  const NavidromeTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.genre,
    this.coverArtId,
    this.track = 1,
    this.year = 2026,
    this.contentType,
    this.bitRate,
  });

  factory NavidromeTrack.fromJson(Map<String, dynamic> json) => NavidromeTrack(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Unknown title',
    artist: json['artist']?.toString() ?? 'Unknown artist',
    album: json['album']?.toString() ?? 'Unknown album',
    duration: Duration(seconds: (json['duration'] as num?)?.toInt() ?? 0),
    genre: json['genre']?.toString(),
    coverArtId: json['coverArt']?.toString(),
    track: (json['track'] as num?)?.toInt() ?? 1,
    year: (json['year'] as num?)?.toInt() ?? 2026,
    contentType: json['contentType']?.toString(),
    bitRate: (json['bitRate'] as num?)?.toInt(),
  );

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String? genre;
  final String? coverArtId;
  final int track;
  final int year;
  final String? contentType;
  final int? bitRate;
}
