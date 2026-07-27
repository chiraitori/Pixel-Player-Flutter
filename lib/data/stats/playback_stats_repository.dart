import 'dart:math';

import '../../core/models/song.dart';

class PlaybackEvent {
  const PlaybackEvent({
    required this.songId,
    required this.startedAt,
    required this.listenedDuration,
  });

  final String songId;
  final DateTime startedAt;
  final Duration listenedDuration;

  PlaybackEvent copyWith({Duration? listenedDuration}) => PlaybackEvent(
    songId: songId,
    startedAt: startedAt,
    listenedDuration: listenedDuration ?? this.listenedDuration,
  );

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'startedAtMs': startedAt.millisecondsSinceEpoch,
    'listenedMs': listenedDuration.inMilliseconds,
  };

  factory PlaybackEvent.fromJson(Map<String, dynamic> json) => PlaybackEvent(
    songId: json['songId'] as String,
    startedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['startedAtMs'] as num).toInt(),
    ),
    listenedDuration: Duration(
      milliseconds: (json['listenedMs'] as num?)?.toInt() ?? 0,
    ),
  );
}

class PlaybackStatsSnapshot {
  const PlaybackStatsSnapshot({
    required this.playCount,
    required this.listeningTime,
    required this.sessionCount,
    required this.averageSession,
    required this.longestSession,
    required this.sessionsPerDay,
    required this.mostActiveDay,
    required this.mostActiveDayDuration,
    required this.peakWindow,
    required this.weekdayDurations,
    required this.weekdayPlayCounts,
    required this.weekdayAveragePlay,
    required this.genreShares,
    required this.songPlayCounts,
    required this.songListeningDurations,
  });

  final int playCount;
  final Duration listeningTime;
  final int sessionCount;
  final Duration averageSession;
  final Duration longestSession;
  final double sessionsPerDay;
  final String mostActiveDay;
  final Duration mostActiveDayDuration;
  final String peakWindow;
  final List<Duration> weekdayDurations;
  final List<int> weekdayPlayCounts;
  final List<Duration> weekdayAveragePlay;
  final List<(String, double)> genreShares;
  final Map<String, int> songPlayCounts;
  final Map<String, Duration> songListeningDurations;
}

class PlaybackStatsRepository {
  const PlaybackStatsRepository();

  static const sessionGap = Duration(minutes: 30);

  PlaybackStatsSnapshot summarize({
    required List<PlaybackEvent> events,
    required List<Song> songs,
    DateTime? start,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final filtered =
        events
            .where((event) => start == null || !event.startedAt.isBefore(start))
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final byId = {for (final song in songs) song.id: song};
    final sessions = <Duration>[];
    var currentSession = Duration.zero;
    DateTime? previousEnd;
    for (final event in filtered) {
      final duration = _effectiveDuration(event, byId[event.songId]);
      final beginsNewSession =
          previousEnd == null ||
          event.startedAt.difference(previousEnd) > sessionGap;
      if (beginsNewSession && currentSession > Duration.zero) {
        sessions.add(currentSession);
        currentSession = Duration.zero;
      }
      currentSession += duration;
      previousEnd = event.startedAt.add(duration);
    }
    if (currentSession > Duration.zero) sessions.add(currentSession);

    final total = filtered.fold(
      Duration.zero,
      (value, event) => value + _effectiveDuration(event, byId[event.songId]),
    );
    final weekday = List<Duration>.filled(7, Duration.zero);
    final weekdayPlayCounts = List<int>.filled(7, 0);
    final hourBuckets = List<Duration>.filled(6, Duration.zero);
    final genreDurations = <String, Duration>{};
    final songPlayCounts = <String, int>{};
    final songListeningDurations = <String, Duration>{};
    for (final event in filtered) {
      final duration = _effectiveDuration(event, byId[event.songId]);
      weekday[event.startedAt.weekday - 1] += duration;
      weekdayPlayCounts[event.startedAt.weekday - 1]++;
      hourBuckets[event.startedAt.hour ~/ 4] += duration;
      final genre = byId[event.songId]?.genre.trim();
      songPlayCounts.update(
        event.songId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      songListeningDurations.update(
        event.songId,
        (value) => value + duration,
        ifAbsent: () => duration,
      );
      if (genre != null && genre.isNotEmpty) {
        genreDurations.update(
          genre,
          (value) => value + duration,
          ifAbsent: () => duration,
        );
      }
    }
    final topWeekdayIndex = _indexOfLargest(weekday);
    final topHourIndex = _indexOfLargest(hourBuckets);
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final genreTotal = max(
      1,
      genreDurations.values.fold(
        0,
        (value, duration) => value + duration.inMilliseconds,
      ),
    );
    final genreShares =
        genreDurations.entries
            .map(
              (entry) => (entry.key, entry.value.inMilliseconds / genreTotal),
            )
            .toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));
    final rangeDays = start == null
        ? _coveredDays(filtered, currentTime)
        : max(1, currentTime.difference(start).inHours / 24);
    return PlaybackStatsSnapshot(
      playCount: filtered.length,
      listeningTime: total,
      sessionCount: sessions.length,
      averageSession: sessions.isEmpty
          ? Duration.zero
          : Duration(milliseconds: total.inMilliseconds ~/ sessions.length),
      longestSession: sessions.fold(
        Duration.zero,
        (value, duration) => duration > value ? duration : value,
      ),
      sessionsPerDay: sessions.length / rangeDays,
      mostActiveDay: filtered.isEmpty ? 'No data' : weekdays[topWeekdayIndex],
      mostActiveDayDuration: weekday[topWeekdayIndex],
      peakWindow: filtered.isEmpty
          ? 'No data'
          : _hourWindowLabel(topHourIndex * 4),
      weekdayDurations: weekday,
      weekdayPlayCounts: weekdayPlayCounts,
      weekdayAveragePlay: [
        for (var index = 0; index < weekday.length; index++)
          Duration(
            milliseconds: weekdayPlayCounts[index] == 0
                ? 0
                : weekday[index].inMilliseconds ~/ weekdayPlayCounts[index],
          ),
      ],
      genreShares: genreShares.take(4).toList(growable: false),
      songPlayCounts: songPlayCounts,
      songListeningDurations: songListeningDurations,
    );
  }

  Duration _effectiveDuration(PlaybackEvent event, Song? song) {
    if (event.listenedDuration > Duration.zero) return event.listenedDuration;
    return song?.duration ?? Duration.zero;
  }

  int _indexOfLargest(List<Duration> values) {
    var result = 0;
    for (var index = 1; index < values.length; index++) {
      if (values[index] > values[result]) result = index;
    }
    return result;
  }

  double _coveredDays(List<PlaybackEvent> events, DateTime now) {
    if (events.isEmpty) return 1;
    return max(1, now.difference(events.first.startedAt).inHours / 24);
  }

  String _hourWindowLabel(int startHour) {
    final endHour = (startHour + 4) % 24;
    return '${_clockHour(startHour)} – ${_clockHour(endHour)}';
  }

  String _clockHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    return hour < 12 ? '$hour AM' : '${hour - 12} PM';
  }
}
