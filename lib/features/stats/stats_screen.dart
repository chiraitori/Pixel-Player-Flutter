import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import '../../data/stats/playback_stats_repository.dart';
import '../../shared/widgets/collapsible_common_top_bar.dart';
import '../player/full_player.dart';
import '../player/mini_player.dart';
import '../../shared/widgets/artwork.dart';

enum _StatsRange { day, week, month, year, all }

enum _TimelineMetric { listeningTime, playCount, averagePlay }

enum _CategoryDimension { genre, artist, album, song }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _StatsRange range = _StatsRange.month;
  _TimelineMetric timelineMetric = _TimelineMetric.listeningTime;
  _CategoryDimension categoryDimension = _CategoryDimension.song;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final controller = AppScope.of(context);
    final snapshot = controller.statsFor(_startFor(range, now));
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
    final miniVisible = controller.currentSong != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: !controller.fullPlayerVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && controller.fullPlayerVisible) {
          controller.hideFullPlayer();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                CollapsibleCommonTopBar(
                  title: 'Listening stats',
                  onBack: () => Navigator.maybePop(context),
                  expandedHeight: 176,
                  maxLines: 2,
                  actions: [
                    IconButton.filledTonal(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _RangeHeaderDelegate(
                    child: _RangeSelector(value: range, onChanged: _setRange),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                ),
                SliverToBoxAdapter(child: _HeroSection(snapshot: snapshot)),
                SliverToBoxAdapter(
                  child: _Timeline(
                    snapshot: snapshot,
                    metric: timelineMetric,
                    onMetricChanged: (value) =>
                        setState(() => timelineMetric = value),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CategoryMetrics(
                    snapshot: snapshot,
                    dimension: categoryDimension,
                    onDimensionChanged: (value) =>
                        setState(() => categoryDimension = value),
                  ),
                ),
                SliverToBoxAdapter(child: _ListeningHabits(snapshot: snapshot)),
                SliverToBoxAdapter(child: _TopArtists(snapshot: snapshot)),
                SliverToBoxAdapter(child: _TopAlbums(snapshot: snapshot)),
                SliverToBoxAdapter(
                  child: _TrackConcentration(snapshot: snapshot),
                ),
                SliverToBoxAdapter(child: _SongStats(snapshot: snapshot)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        systemBottom +
                        (miniVisible
                            ? miniPlayerHeight + miniPlayerBottomSpacer
                            : 0) +
                        24,
                  ),
                ),
              ],
            ),
            if (miniVisible && !controller.fullPlayerVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: systemBottom,
                child: const MiniPlayer(key: ValueKey('stats-mini-player')),
              ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !controller.fullPlayerVisible,
                child: AnimatedSlide(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: controller.fullPlayerVisible
                      ? Offset.zero
                      : const Offset(0, 1),
                  child: TickerMode(
                    enabled: controller.fullPlayerVisible,
                    child: const FullPlayer(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setRange(_StatsRange next) => setState(() => range = next);

  DateTime? _startFor(_StatsRange range, DateTime now) => switch (range) {
    _StatsRange.day => DateTime(now.year, now.month, now.day),
    _StatsRange.week => DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - DateTime.monday),
    ),
    _StatsRange.month => DateTime(now.year, now.month),
    _StatsRange.year => DateTime(now.year),
    _StatsRange.all => null,
  };
}

class _RangeHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _RangeHeaderDelegate({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  double get minExtent => 58;

  @override
  double get maxExtent => 58;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(color: color, child: child);
  }

  @override
  bool shouldRebuild(covariant _RangeHeaderDelegate oldDelegate) {
    return child != oldDelegate.child || color != oldDelegate.color;
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});

  final _StatsRange value;
  final ValueChanged<_StatsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        scrollDirection: Axis.horizontal,
        children: [
          for (final item in _StatsRange.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: item == value,
                onSelected: (_) => onChanged(item),
                label: Text(switch (item) {
                  _StatsRange.day => 'Day',
                  _StatsRange.week => 'Week',
                  _StatsRange.month => 'Month',
                  _StatsRange.year => 'Year',
                  _StatsRange.all => 'All time',
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.snapshot});

  final PlaybackStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final duration = snapshot.listeningTime;
    final durationLabel = duration.inHours > 0
        ? '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
        : '${duration.inMinutes}m';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _HeroCard(
              icon: Icons.headphones_rounded,
              value: durationLabel,
              label: 'Listening',
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _HeroCard(
              icon: Icons.play_circle_rounded,
              value: '${snapshot.playCount}',
              label: 'Plays',
              color: Theme.of(context).colorScheme.tertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 154,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32),
          const Spacer(),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(label),
        ],
      ),
    );
  }
}

class _ListeningHabits extends StatelessWidget {
  const _ListeningHabits({required this.snapshot});

  final PlaybackStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _StatsCard(
      title: 'Listening habits',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric('${snapshot.sessionCount}', 'Total sessions'),
              ),
              Expanded(
                child: _Metric(
                  _formatDuration(snapshot.averageSession),
                  'Average session',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  _formatDuration(snapshot.longestSession),
                  'Longest session',
                ),
              ),
              Expanded(
                child: _Metric(
                  snapshot.sessionsPerDay.toStringAsFixed(1),
                  'Sessions per day',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Highlight(
            icon: Icons.calendar_today_rounded,
            title: 'Most active day',
            value: snapshot.mostActiveDay,
            detail:
                '${_formatDuration(snapshot.mostActiveDayDuration)} of listening',
          ),
          const SizedBox(height: 8),
          _Highlight(
            icon: Icons.schedule_rounded,
            title: 'Peak time',
            value: snapshot.peakWindow,
            detail: 'Your favorite listening window',
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    return '${duration.inMinutes}m';
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelMedium),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.snapshot,
    required this.metric,
    required this.onMetricChanged,
  });

  final PlaybackStatsSnapshot snapshot;
  final _TimelineMetric metric;
  final ValueChanged<_TimelineMetric> onMetricChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final values = switch (metric) {
      _TimelineMetric.listeningTime => [
        for (final value in snapshot.weekdayDurations)
          value.inMilliseconds.toDouble(),
      ],
      _TimelineMetric.playCount => [
        for (final value in snapshot.weekdayPlayCounts) value.toDouble(),
      ],
      _TimelineMetric.averagePlay => [
        for (final value in snapshot.weekdayAveragePlay)
          value.inMilliseconds.toDouble(),
      ],
    };
    final maxValue = values.fold<double>(
      1,
      (largest, value) => value > largest ? value : largest,
    );
    final peakIndex = values.indexOf(maxValue);
    return _StatsCard(
      title: 'Listening timeline',
      subtitle: 'Daily rhythm • grouped by weekday',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in _TimelineMetric.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: metric == item,
                      onSelected: (_) => onMetricChanged(item),
                      label: Text(switch (item) {
                        _TimelineMetric.listeningTime => 'Listening time',
                        _TimelineMetric.playCount => 'Play count',
                        _TimelineMetric.averagePlay => 'Average session',
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < values.length; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _timelineValueLabel(metric, values[index]),
                            maxLines: 1,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: values[index] / maxValue,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: index == peakIndex
                                        ? colors.primary
                                        : colors.secondaryContainer,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timelineValueLabel(_TimelineMetric metric, double value) {
    if (value <= 0) return '0';
    return switch (metric) {
      _TimelineMetric.playCount => value.round().toString(),
      _TimelineMetric.listeningTime || _TimelineMetric.averagePlay =>
        _compactDuration(Duration(milliseconds: value.round())),
    };
  }

  String _compactDuration(Duration duration) {
    if (duration.inHours > 0) return '${duration.inHours}h';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m';
    return '${duration.inSeconds}s';
  }
}

class _CategoryMetrics extends StatelessWidget {
  const _CategoryMetrics({
    required this.snapshot,
    required this.dimension,
    required this.onDimensionChanged,
  });

  final PlaybackStatsSnapshot snapshot;
  final _CategoryDimension dimension;
  final ValueChanged<_CategoryDimension> onDimensionChanged;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final values = _entries(controller);
    final maximum = values.fold<double>(
      1,
      (largest, entry) => entry.$2 > largest ? entry.$2 : largest,
    );
    return _StatsCard(
      title: 'Top categories',
      subtitle: 'What shaped your listening',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in _CategoryDimension.values.reversed)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: dimension == item,
                      onSelected: (_) => onDimensionChanged(item),
                      label: Text(switch (item) {
                        _CategoryDimension.genre => 'Genres',
                        _CategoryDimension.artist => 'Artists',
                        _CategoryDimension.album => 'Albums',
                        _CategoryDimension.song => 'Songs',
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (values.isEmpty)
            const Text('Play some music to build your listening stats.')
          else
            for (var index = 0; index < values.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index == 0
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Text('${index + 1}'),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 92,
                      child: Text(
                        values[index].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: values[index].$2 / maximum,
                        minHeight: 15,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${values[index].$2.round()}'),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  List<(String, double)> _entries(AppController controller) {
    if (dimension == _CategoryDimension.genre) {
      return [
        for (final entry in snapshot.genreShares)
          (entry.$1, entry.$2 * snapshot.playCount),
      ];
    }
    if (dimension == _CategoryDimension.artist) {
      final entries = [
        for (final artist in controller.artists)
          (
            artist.name,
            artist.songs.fold<double>(
              0,
              (total, song) => total + (snapshot.songPlayCounts[song.id] ?? 0),
            ),
          ),
      ]..removeWhere((entry) => entry.$2 <= 0);
      entries.sort((a, b) => b.$2.compareTo(a.$2));
      return entries.take(5).toList(growable: false);
    }
    if (dimension == _CategoryDimension.album) {
      final entries = [
        for (final album in controller.albums)
          (
            album.title,
            album.songs.fold<double>(
              0,
              (total, song) => total + (snapshot.songPlayCounts[song.id] ?? 0),
            ),
          ),
      ]..removeWhere((entry) => entry.$2 <= 0);
      entries.sort((a, b) => b.$2.compareTo(a.$2));
      return entries.take(5).toList(growable: false);
    }
    final songsById = {for (final song in controller.songs) song.id: song};
    final entries = [
      for (final entry in snapshot.songPlayCounts.entries)
        if (songsById[entry.key] case final song?)
          (song.title, entry.value.toDouble()),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return entries.take(5).toList(growable: false);
  }
}

class _TopArtists extends StatelessWidget {
  const _TopArtists({required this.snapshot});

  final PlaybackStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final artists = [...controller.artists]
      ..sort((a, b) {
        final bCount = b.songs.fold(
          0,
          (total, song) => total + (snapshot.songPlayCounts[song.id] ?? 0),
        );
        final aCount = a.songs.fold(
          0,
          (total, song) => total + (snapshot.songPlayCounts[song.id] ?? 0),
        );
        return bCount.compareTo(aCount);
      })
      ..removeWhere(
        (artist) => artist.songs.every(
          (song) => (snapshot.songPlayCounts[song.id] ?? 0) == 0,
        ),
      );
    return _StatsCard(
      title: 'Top artists',
      child: artists.isEmpty
          ? const Text(
              'Your top artists will appear after you start listening.',
            )
          : Column(
              children: [
                for (
                  var index = 0;
                  index < artists.length && index < 10;
                  index++
                )
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipOval(
                      child: Artwork(
                        colors: artists[index].colors,
                        size: 50,
                        borderRadius: 0,
                        mediaStoreId: artists[index].songs.first.mediaStoreId,
                      ),
                    ),
                    title: Text(artists[index].name),
                    subtitle: Text(
                      '${artists[index].songs.fold(0, (total, song) => total + (snapshot.songPlayCounts[song.id] ?? 0))} plays',
                    ),
                    trailing: Text('#${index + 1}'),
                  ),
              ],
            ),
    );
  }
}

class _TopAlbums extends StatelessWidget {
  const _TopAlbums({required this.snapshot});

  final PlaybackStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final albums = [...controller.albums]
      ..sort((a, b) {
        final bCount = b.songs.fold(
          0,
          (total, song) => total + (snapshot.songPlayCounts[song.id] ?? 0),
        );
        final aCount = a.songs.fold(
          0,
          (total, song) => total + (snapshot.songPlayCounts[song.id] ?? 0),
        );
        return bCount.compareTo(aCount);
      })
      ..removeWhere(
        (album) => album.songs.every(
          (song) => (snapshot.songPlayCounts[song.id] ?? 0) == 0,
        ),
      );
    return _StatsCard(
      title: 'Top albums',
      child: albums.isEmpty
          ? const Text('Your top albums will appear after you start listening.')
          : SizedBox(
              height: 174,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: albums.length > 10 ? 10 : albums.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final album = albums[index];
                  return SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Artwork(
                          colors: album.colors,
                          size: 120,
                          borderRadius: 16,
                          mediaStoreId: album.songs.first.mediaStoreId,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          album.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${album.songs.fold(0, (total, song) => total + (snapshot.songPlayCounts[song.id] ?? 0))} plays',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _TrackConcentration extends StatelessWidget {
  const _TrackConcentration({required this.snapshot});

  final PlaybackStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final counts = snapshot.songPlayCounts.values.toList()
      ..sort((a, b) => b.compareTo(a));
    final totalPlays = counts.fold<int>(0, (total, count) => total + count);
    final topTenPlays = counts
        .take(10)
        .fold<int>(0, (total, count) => total + count);
    final concentration = totalPlays == 0 ? 0.0 : topTenPlays / totalPlays;
    final repeatedTracks = counts.where((count) => count > 1).length;
    return _StatsCard(
      title: 'Track concentration',
      subtitle: 'How focused or varied your listening was',
      child: totalPlays == 0
          ? const Text('Track distribution appears after you play music.')
          : Row(
              children: [
                SizedBox.square(
                  dimension: 112,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 100,
                        child: CircularProgressIndicator(
                          value: concentration,
                          strokeWidth: 14,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(concentration * 100).round()}%',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'top 10',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      _DistributionMetric(
                        label: 'Unique tracks',
                        value: '${counts.length}',
                      ),
                      const SizedBox(height: 14),
                      _DistributionMetric(
                        label: 'Repeated tracks',
                        value: '$repeatedTracks',
                      ),
                      const SizedBox(height: 14),
                      _DistributionMetric(
                        label: 'Total plays',
                        value: '$totalPlays',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DistributionMetric extends StatelessWidget {
  const _DistributionMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _SongStats extends StatefulWidget {
  const _SongStats({required this.snapshot});

  final PlaybackStatsSnapshot snapshot;

  @override
  State<_SongStats> createState() => _SongStatsState();
}

class _SongStatsState extends State<_SongStats> {
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final songs = [...controller.songs]
      ..removeWhere(
        (song) => (widget.snapshot.songPlayCounts[song.id] ?? 0) == 0,
      )
      ..sort(
        (a, b) => (widget.snapshot.songPlayCounts[b.id] ?? 0).compareTo(
          widget.snapshot.songPlayCounts[a.id] ?? 0,
        ),
      );
    final visible = showAll ? songs : songs.take(5).toList(growable: false);
    return _StatsCard(
      title: 'Song stats',
      subtitle: 'Your most replayed tracks',
      child: songs.isEmpty
          ? const Text('Song rankings appear after you start listening.')
          : Column(
              children: [
                for (var index = 0; index < visible.length; index++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Artwork(
                          colors: visible[index].colors,
                          size: 48,
                          borderRadius: 12,
                          mediaStoreId: visible[index].mediaStoreId,
                        ),
                        Positioned(
                          left: -6,
                          top: -6,
                          child: CircleAvatar(
                            radius: 11,
                            child: Text(
                              '${index + 1}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      visible[index].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      visible[index].artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      '${widget.snapshot.songPlayCounts[visible[index].id]} plays',
                    ),
                  ),
                if (songs.length > 5)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => setState(() => showAll = !showAll),
                      icon: Icon(
                        showAll
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                      ),
                      label: Text(showAll ? 'Show less' : 'Show all'),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
