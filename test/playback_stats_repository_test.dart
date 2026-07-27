import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/data/stats/playback_stats_repository.dart';

import 'fixtures/mock_library.dart';

void main() {
  const repository = PlaybackStatsRepository();

  test('derives sessions, timeline, peak window, and genres from events', () {
    final monday = DateTime(2026, 7, 20, 20);
    final events = [
      PlaybackEvent(
        songId: MockLibrary.songs[0].id,
        startedAt: monday,
        listenedDuration: const Duration(minutes: 10),
      ),
      PlaybackEvent(
        songId: MockLibrary.songs[1].id,
        startedAt: monday.add(const Duration(minutes: 20)),
        listenedDuration: const Duration(minutes: 20),
      ),
      PlaybackEvent(
        songId: MockLibrary.songs[0].id,
        startedAt: monday.add(const Duration(hours: 2)),
        listenedDuration: const Duration(minutes: 15),
      ),
    ];

    final result = repository.summarize(
      events: events,
      songs: MockLibrary.songs,
      now: monday.add(const Duration(days: 1)),
    );

    expect(result.playCount, 3);
    expect(result.listeningTime, const Duration(minutes: 45));
    expect(result.sessionCount, 2);
    expect(result.longestSession, const Duration(minutes: 30));
    expect(
      result.weekdayDurations[monday.weekday - 1],
      const Duration(minutes: 45),
    );
    expect(result.peakWindow, '8 PM – 12 AM');
    expect(result.songPlayCounts[MockLibrary.songs[0].id], 2);
    expect(result.genreShares.first.$1, MockLibrary.songs[0].genre);
  });

  test('honors the selected range start', () {
    final now = DateTime(2026, 7, 25, 12);
    final result = repository.summarize(
      events: [
        PlaybackEvent(
          songId: MockLibrary.songs.first.id,
          startedAt: now.subtract(const Duration(days: 2)),
          listenedDuration: const Duration(minutes: 10),
        ),
        PlaybackEvent(
          songId: MockLibrary.songs.first.id,
          startedAt: now.subtract(const Duration(hours: 1)),
          listenedDuration: const Duration(minutes: 5),
        ),
      ],
      songs: MockLibrary.songs,
      start: DateTime(now.year, now.month, now.day),
      now: now,
    );

    expect(result.playCount, 1);
    expect(result.listeningTime, const Duration(minutes: 5));
  });
}
