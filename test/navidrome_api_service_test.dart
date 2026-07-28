import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/data/providers/navidrome/navidrome_api_service.dart';

void main() {
  test(
    'Navidrome dashboard models preserve Subsonic playlist and track fields',
    () {
      final playlist = NavidromePlaylist.fromJson(const {
        'id': 'mix-42',
        'name': 'Late Night',
        'songCount': 18,
        'coverArt': 'cover-42',
      });
      final track = NavidromeTrack.fromJson(const {
        'id': 'song-5',
        'title': 'Afterglow',
        'artist': 'Pixel Artist',
        'album': 'Night Drive',
        'duration': 214,
        'genre': 'Electronic',
        'track': 5,
        'year': 2025,
        'bitRate': 320,
      });

      expect(playlist.name, 'Late Night');
      expect(playlist.songCount, 18);
      expect(track.duration, const Duration(seconds: 214));
      expect(track.bitRate, 320);
    },
  );
}
