import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/data/mixes/daily_mix_manager.dart';

import 'fixtures/mock_library.dart';

void main() {
  const manager = DailyMixManager();
  final date = DateTime(2026, 7, 25, 12);

  test('daily mix is stable for the same calendar day', () {
    final engagements = {
      MockLibrary.songs.first.id: SongEngagement(
        playCount: 12,
        totalPlayDuration: const Duration(minutes: 42),
        lastPlayed: date.subtract(const Duration(days: 3)),
      ),
    };
    final first = manager.generateDailyMix(
      allSongs: MockLibrary.songs,
      favoriteSongIds: {MockLibrary.songs[1].id},
      engagements: engagements,
      date: date,
    );
    final second = manager.generateDailyMix(
      allSongs: MockLibrary.songs,
      favoriteSongIds: {MockLibrary.songs[1].id},
      engagements: engagements,
      date: date,
    );

    expect(first.map((song) => song.id), second.map((song) => song.id));
    expect(first.map((song) => song.id).toSet().length, first.length);
  });

  test('your mix never duplicates songs or exceeds its limit', () {
    final result = manager.generateYourMix(
      allSongs: MockLibrary.songs,
      favoriteSongIds: MockLibrary.songs.take(3).map((song) => song.id).toSet(),
      engagements: const {},
      limit: 7,
      date: date,
    );

    expect(result, hasLength(7));
    expect(result.map((song) => song.id).toSet(), hasLength(7));
  });
}
