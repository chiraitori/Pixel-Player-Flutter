import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/data/lyrics_parser.dart';
import 'package:pixelplayer_flutter/core/data/lyrics_service.dart';
import 'package:pixelplayer_flutter/core/models/lyrics.dart';
import 'package:pixelplayer_flutter/core/models/song.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final service = LyricsService.instance;

  test(
    'embedded metadata prefers synced lyrics over an earlier plain field',
    () {
      final lyrics = service.bestEmbeddedLyricsForTesting({
        'LYRICS': ['plain lyrics only'],
        'SYNCEDLYRICS': ['[00:01.00]Synced lyrics'],
      });

      expect(lyrics, isNotNull);
      expect(lyrics!.hasSynced, isTrue);
      expect(lyrics.synced.single.text, 'Synced lyrics');
    },
  );

  test(
    'bulk scan assigns a matching sidecar LRC and reset clears it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp('pixelplay_lrc_');
      addTearDown(() => directory.delete(recursive: true));
      final audio = File(
        '${directory.path}${Platform.pathSeparator}Track.flac',
      );
      final lrc = File('${directory.path}${Platform.pathSeparator}Track.lrc');
      await audio.writeAsBytes(const [0]);
      await lrc.writeAsString('[00:01.00]Found beside the song');
      final song = _song(
        id: 'sidecar-test',
        title: 'Track',
        artist: 'Artist',
        path: audio.path,
      );

      expect(await service.scanAndAssignLocalFiles([song]), 1);
      final stored = await service.lyricsFor(song, includeRemote: false);
      expect(stored?.synced.single.text, 'Found beside the song');

      await service.resetAllLyrics();
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('lyrics_content_sidecar-test'), isNull);
    },
  );

  test('automatic matching rejects a duration-only result', () {
    final song = _song(title: 'Actual Song', artist: 'Actual Artist');
    final results = service.rankRemoteResultsForTesting(song, [
      _result(title: 'Completely Different Song', artist: 'Different Artist'),
    ]);

    expect(results, isEmpty);
  });

  test('automatic matching rejects original lyrics for a remix', () {
    final song = _song(
      title: 'Midnight City (Remix)',
      artist: 'M83',
      path: r'C:\Music\Midnight City (Remix).mp3',
    );
    final results = service.rankRemoteResultsForTesting(song, [
      _result(title: 'Midnight City', artist: 'M83'),
    ]);

    expect(results, isEmpty);
  });

  test('automatic matching accepts the same remix variant', () {
    final song = _song(
      title: 'Midnight City (Eric Prydz Remix)',
      artist: 'M83',
      path: r'C:\Music\Midnight City (Eric Prydz Remix).mp3',
    );
    final matching = _result(
      title: 'Midnight City (Eric Prydz Remix)',
      artist: 'M83',
    );
    final results = service.rankRemoteResultsForTesting(song, [matching]);

    expect(results, [matching]);
  });

  test('artist word mix in a file name is not treated as a remix variant', () {
    final song = _song(
      title: 'Black Magic',
      artist: 'Little Mix',
      path: r'C:\Music\Little Mix - Black Magic.mp3',
    );
    final matching = _result(title: 'Black Magic', artist: 'Little Mix');
    final results = service.rankRemoteResultsForTesting(song, [matching]);

    expect(results, [matching]);
  });
}

Song _song({
  String id = '1',
  required String title,
  required String artist,
  String? path,
}) {
  return Song(
    id: id,
    title: title,
    artist: artist,
    album: 'Album',
    genre: 'Pop',
    duration: const Duration(seconds: 180),
    colors: const [Color(0xFF40578A), Color(0xFF121318)],
    path: path,
  );
}

LyricsSearchResult _result({required String title, required String artist}) {
  return LyricsSearchResult(
    id: Object.hash(title, artist),
    trackName: title,
    artistName: artist,
    albumName: 'Album',
    duration: const Duration(seconds: 180),
    document: LyricsParser.parse(
      '[00:01.00]First line\n[00:05.00]Second line',
      fromRemote: true,
    ),
  );
}
