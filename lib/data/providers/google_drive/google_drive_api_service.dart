import 'dart:convert';
import 'dart:io';

import '../../../core/app_info.dart';

class GoogleDriveApiService {
  const GoogleDriveApiService({required this.accessToken});

  final String accessToken;

  static const audioMimeTypes = <String>{
    'audio/mpeg',
    'audio/mp3',
    'audio/flac',
    'audio/wav',
    'audio/x-wav',
    'audio/mp4',
    'audio/x-m4a',
    'audio/aac',
    'audio/ogg',
    'audio/opus',
    'audio/x-aiff',
    'audio/alac',
    'audio/aiff',
    'audio/x-flac',
    'audio/vnd.wave',
    'audio/midi',
    'audio/x-midi',
    'audio/sp-midi',
    'audio/x-mid',
  };

  Future<List<GoogleDriveAudioFile>> listAudioFiles({
    required String folderId,
  }) async {
    final files = <GoogleDriveAudioFile>[];
    String? pageToken;
    final mimeQuery = audioMimeTypes
        .map((mime) => "mimeType='${_escapeQuery(mime)}'")
        .join(' or ');
    do {
      final query =
          "'${_escapeQuery(folderId)}' in parents and "
          '($mimeQuery) and trashed=false';
      final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
        'q': query,
        'fields':
            'nextPageToken,files('
            'id,name,mimeType,size,modifiedTime,thumbnailLink)',
        'pageSize': '100',
        'orderBy': 'name',
        'pageToken': ?pageToken,
      });
      final decoded = await _request(uri);
      final rawFiles = decoded['files'];
      if (rawFiles is List) {
        for (final rawFile in rawFiles) {
          if (rawFile is! Map) continue;
          final file = GoogleDriveAudioFile.fromJson(
            Map<String, dynamic>.from(rawFile),
          );
          if (file.id.isNotEmpty && file.name.isNotEmpty) files.add(file);
        }
      }
      pageToken = decoded['nextPageToken']?.toString();
      if (pageToken?.isEmpty == true) pageToken = null;
    } while (pageToken != null);
    return files;
  }

  Uri streamUri(String fileId) => Uri(
    scheme: 'https',
    host: 'www.googleapis.com',
    pathSegments: ['drive', 'v3', 'files', fileId],
    queryParameters: const {'alt': 'media'},
  );

  Future<List<GoogleDriveFolder>> listFolders({
    String parentId = 'root',
  }) async {
    final folders = <GoogleDriveFolder>[];
    String? pageToken;
    do {
      final query =
          "'${_escapeQuery(parentId)}' in parents and "
          "mimeType='application/vnd.google-apps.folder' and trashed=false";
      final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
        'q': query,
        'fields': 'nextPageToken,files(id,name)',
        'pageSize': '100',
        'orderBy': 'name',
        'pageToken': ?pageToken,
      });
      final decoded = await _request(uri);
      final files = decoded['files'];
      if (files is List) {
        for (final file in files) {
          if (file is! Map) continue;
          final id = file['id']?.toString() ?? '';
          final name = file['name']?.toString() ?? '';
          if (id.isNotEmpty && name.isNotEmpty) {
            folders.add(GoogleDriveFolder(id: id, name: name));
          }
        }
      }
      pageToken = decoded['nextPageToken']?.toString();
      if (pageToken?.isEmpty == true) pageToken = null;
    } while (pageToken != null);
    return folders;
  }

  Future<GoogleDriveFolder> createFolder({
    required String name,
    String parentId = 'root',
  }) async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'fields': 'id,name',
    });
    final decoded = await _request(
      uri,
      method: 'POST',
      body: jsonEncode({
        'name': name,
        'mimeType': 'application/vnd.google-apps.folder',
        'parents': [parentId],
      }),
    );
    final id = decoded['id']?.toString() ?? '';
    final returnedName = decoded['name']?.toString() ?? name;
    if (id.isEmpty) {
      throw const GoogleDriveApiException(
        'Google Drive did not return the created folder.',
      );
    }
    return GoogleDriveFolder(id: id, name: returnedName);
  }

  Future<Map<String, dynamic>> _request(
    Uri uri, {
    String method = 'GET',
    String? body,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = method == 'POST'
          ? await client.postUrl(uri)
          : await client.getUrl(uri);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
        ..set(HttpHeaders.acceptHeader, ContentType.json.mimeType)
        ..set(HttpHeaders.userAgentHeader, AppInfo.userAgent);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(body);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 35),
      );
      final responseBody = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GoogleDriveApiException(
          _errorMessage(response.statusCode, responseBody),
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map) {
        throw const GoogleDriveApiException(
          'Google Drive returned an invalid response.',
        );
      }
      return Map<String, dynamic>.from(decoded);
    } on GoogleDriveApiException {
      rethrow;
    } on SocketException {
      throw const GoogleDriveApiException('Could not connect to Google Drive.');
    } finally {
      client.close(force: true);
    }
  }

  String _errorMessage(int code, String body) {
    String? message;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        message = (decoded['error'] as Map)['message']?.toString();
      }
    } catch (_) {
      // Use safe fallback below.
    }
    return switch (code) {
      401 => 'Google Drive authorization expired. Sign in again.',
      403 => message ?? 'Google Drive permission was denied.',
      404 => 'The selected Google Drive folder no longer exists.',
      429 => 'Google Drive rate limit reached. Try again shortly.',
      >= 500 => 'Google Drive is temporarily unavailable.',
      _ => message ?? 'Google Drive request failed ($code).',
    };
  }

  String _escapeQuery(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
}

class GoogleDriveFolder {
  const GoogleDriveFolder({required this.id, required this.name});

  final String id;
  final String name;
}

class GoogleDriveAudioFile {
  const GoogleDriveAudioFile({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.modifiedTime,
    this.thumbnailLink,
  });

  factory GoogleDriveAudioFile.fromJson(Map<String, dynamic> json) {
    return GoogleDriveAudioFile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? 'audio/mpeg',
      size: int.tryParse(json['size']?.toString() ?? '') ?? 0,
      modifiedTime:
          DateTime.tryParse(json['modifiedTime']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      thumbnailLink: _nonBlank(json['thumbnailLink']),
    );
  }

  final String id;
  final String name;
  final String mimeType;
  final int size;
  final DateTime modifiedTime;
  final String? thumbnailLink;

  String get filenameWithoutExtension {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  String get artist {
    final separator = filenameWithoutExtension.indexOf(' - ');
    return separator <= 0
        ? 'Unknown Artist'
        : filenameWithoutExtension.substring(0, separator).trim();
  }

  String get title {
    final separator = filenameWithoutExtension.indexOf(' - ');
    return separator <= 0
        ? filenameWithoutExtension.trim()
        : filenameWithoutExtension.substring(separator + 3).trim();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mimeType': mimeType,
    'size': size,
    'modifiedTime': modifiedTime.toUtc().toIso8601String(),
    if (thumbnailLink != null) 'thumbnailLink': thumbnailLink,
  };

  static String? _nonBlank(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class GoogleDriveApiException implements Exception {
  const GoogleDriveApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
