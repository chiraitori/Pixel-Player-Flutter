import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/song.dart';
import '../../../data/stats/playback_stats_repository.dart';

/// Source-parity port of Compose `StatsOverviewCard`.
class StatsOverviewCard extends StatelessWidget {
  const StatsOverviewCard({
    required this.snapshot,
    required this.songs,
    required this.onTap,
    super.key,
  });

  final PlaybackStatsSnapshot snapshot;
  final List<Song> songs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final topTrack = _resolveTopTrack();
    final averagePerDay = Duration(
      milliseconds: snapshot.listeningTime.inMilliseconds ~/ 7,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: colors.surfaceContainerHigh,
        elevation: 0,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ColoredBox(
            color: colors.primary.withValues(alpha: .07),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ColoredBox(
                  color: colors.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Listening stats',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Week to Date',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: colors.primaryContainer,
                          shape: const CircleBorder(),
                          child: SizedBox.square(
                            dimension: 40,
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatLong(snapshot.listeningTime),
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatValue(
                              label: 'Total plays',
                              value: '${snapshot.playCount}',
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _StatValue(
                              label: 'Avg per day',
                              value: _formatCompact(averagePerDay),
                            ),
                          ),
                        ],
                      ),
                      if (topTrack != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Top track',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          topTrack.$1.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${topTrack.$1.artist} • ${topTrack.$2} plays',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _WeeklyListeningTimeline(
                        durations: snapshot.weekdayDurations,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Song, int)? _resolveTopTrack() {
    if (snapshot.songPlayCounts.isEmpty) return null;
    final byId = {for (final song in songs) song.id: song};
    final entries = snapshot.songPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in entries) {
      final song = byId[entry.key];
      if (song != null) return (song, entry.value);
    }
    return null;
  }

  String _formatLong(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    if (hours > 0 && minutes > 0) return '$hours hr $minutes min';
    if (hours > 0) return '$hours hr';
    if (minutes > 0) return '$minutes min';
    return '$seconds sec';
  }

  String _formatCompact(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';
    return '${seconds}s';
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _WeeklyListeningTimeline extends StatelessWidget {
  const _WeeklyListeningTimeline({required this.durations});

  final List<Duration> durations;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final values = [
      for (var index = 0; index < 7; index++)
        index < durations.length ? durations[index] : Duration.zero,
    ];
    final maxMilliseconds = math.max(
      1,
      values.fold<int>(
        0,
        (current, duration) => math.max(current, duration.inMilliseconds),
      ),
    );
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < values.length; index++) ...[
            if (index > 0) const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: double.infinity,
                    height: math.max(
                      10,
                      70 * values[index].inMilliseconds / maxMilliseconds,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[index],
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
