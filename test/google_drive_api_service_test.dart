import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/data/providers/google_drive/google_drive_api_service.dart';

void main() {
  test('Drive audio metadata matches Kotlin filename parsing', () {
    final file = GoogleDriveAudioFile.fromJson({
      'id': 'drive-file-1',
      'name': 'Riria. - "Itsuka Chanto.".flac',
      'mimeType': 'audio/flac',
      'size': '123456',
      'modifiedTime': '2026-07-26T10:20:30.000Z',
      'thumbnailLink': 'https://example.test/thumb',
    });

    expect(file.artist, 'Riria.');
    expect(file.title, '"Itsuka Chanto."');
    expect(file.size, 123456);
    expect(file.mimeType, 'audio/flac');
    expect(
      GoogleDriveAudioFile.fromJson(file.toJson()).toJson(),
      file.toJson(),
    );
  });

  test('Drive stream URL uses the files alt=media endpoint', () {
    const api = GoogleDriveApiService(accessToken: 'not-a-real-token');
    final uri = api.streamUri('a file/id');

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.googleapis.com');
    expect(uri.pathSegments, ['drive', 'v3', 'files', 'a file/id']);
    expect(uri.queryParameters['alt'], 'media');
  });
}
