import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/models/song.dart';
import 'package:pixelplayer_flutter/core/services/playlist_transfer_service.dart';

void main() {
  const first = Song(
    id: 'inside',
    title: 'Inside',
    artist: 'Robin',
    album: 'Inside',
    genre: 'Pop',
    duration: Duration(minutes: 3),
    colors: [Colors.purple],
    path: '/Music/Robin/Inside.flac',
  );
  const second = Song(
    id: 'sleep',
    title: 'Sleep',
    artist: 'LUNE',
    album: 'K-NEXT',
    genre: 'Pop',
    duration: Duration(minutes: 2),
    colors: [Colors.blue],
    contentUri: 'content://media/external/audio/Sleep.mp3',
  );

  test('M3U import mirrors Kotlin exact-path then filename matching', () {
    final imported = PlaylistTransferService.parseM3u(
      '#EXTM3U\n#EXTINF:180,Robin - Inside\n/Music/Robin/Inside.flac\n'
      '/other/device/Sleep.mp3\n'
      '/missing/Nope.flac\n',
      fileName: 'Night Drive.m3u8',
      library: const [first, second],
    );

    expect(imported.name, 'Night Drive');
    expect(imported.songIds, const ['inside', 'sleep']);
  });
}
