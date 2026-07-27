import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/services/audio_meta_service.dart';

void main() {
  group('AudioMetaService format resolution', () {
    test(
      'uses the file extension over a wrong generic MediaStore MIME type',
      () {
        expect(
          AudioMetaService.formatFor(
            filePath: '/Music/live-set.opus',
            mimeType: 'audio/mp4',
          ),
          'OPUS',
        );
        expect(
          AudioMetaService.resolveMimeType(
            filePath: '/Music/archive.flac',
            reportedMimeType: 'audio/mp4',
          ),
          'audio/flac',
        );
      },
    );

    test('uses a concrete native codec over a misleading file extension', () {
      expect(
        AudioMetaService.formatFor(
          filePath: '/Music/lossless-download.m4a',
          mimeType: 'audio/flac',
        ),
        'FLAC',
      );
      expect(
        AudioMetaService.resolveMimeType(
          filePath: '/Music/lossless-download.m4a',
          reportedMimeType: 'audio/flac',
        ),
        'audio/flac',
      );
    });

    test('recognizes common local audio formats from their filenames', () {
      expect(AudioMetaService.formatFor(filePath: '/Music/song.mp3'), 'MP3');
      expect(
        AudioMetaService.formatFor(filePath: 'file:///Music/song.m4a'),
        'M4A',
      );
      expect(AudioMetaService.formatFor(filePath: '/Music/song.flac'), 'FLAC');
      expect(AudioMetaService.formatFor(filePath: '/Music/song.ogg'), 'OGG');
      expect(AudioMetaService.formatFor(filePath: '/Music/song.opus'), 'OPUS');
    });
  });
}
