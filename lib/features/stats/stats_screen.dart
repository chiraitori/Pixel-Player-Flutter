import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/rounded_star_clipper.dart';
import '../../data/stats/playback_stats_repository.dart';
import '../../shared/widgets/collapsible_common_top_bar.dart';
import '../player/full_player.dart';
import '../player/mini_player.dart';
import '../library/widgets/tab_animation.dart';
import '../../shared/widgets/artwork.dart';

enum _StatsRange { day, week, month, year, all }

enum _TimelineMetric { listeningTime, playCount, averagePlay }

enum _CategoryDimension { genre, artist, album, song }

String _formatStatsDuration(Duration duration) {
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  if (duration.inMinutes > 0) return '${duration.inMinutes}m';
  return '${duration.inSeconds}s';
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _StatsRange range = _StatsRange.week;
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
                    range: range,
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
  double get minExtent => 62;

  @override
  double get maxExtent => 62;

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
    final selectedIndex = _StatsRange.values.indexOf(value);
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 62,
      child: Align(
        alignment: Alignment.centerLeft,
        child: ListView.builder(
          key: const ValueKey('stats-range-tabs'),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemCount: _StatsRange.values.length,
          itemBuilder: (context, index) {
            final item = _StatsRange.values[index];
            final label = switch (item) {
              _StatsRange.day => 'Day',
              _StatsRange.week => 'Week',
              _StatsRange.month => 'Month',
              _StatsRange.year => 'Year',
              _StatsRange.all => 'All time',
            };
            return TabAnimation(
              index: index,
              selectedIndex: selectedIndex,
              title: label,
              onTap: () => onChanged(item),
              selectedColor: colors.primary,
              onSelectedColor: colors.onPrimary,
              unselectedColor: colors.surfaceContainerLowest,
              onUnselectedColor: colors.onSurfaceVariant,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: index == selectedIndex
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
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
    final hasData = duration > Duration.zero || snapshot.playCount > 0;
    final durationLabel = duration.inHours > 0
        ? '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
        : '${duration.inMinutes}m';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _HeroCard(
                key: const ValueKey('stats-listening-hero'),
                value: hasData ? durationLabel : '--',
                label: 'Listening',
                containerColor: Theme.of(context).colorScheme.primaryContainer,
                contentColor: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HeroCard(
                key: const ValueKey('stats-plays-hero'),
                value: hasData ? '${snapshot.playCount}' : '--',
                label: 'Plays',
                containerColor: Theme.of(context).colorScheme.tertiaryContainer,
                contentColor: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.value,
    required this.label,
    required this.containerColor,
    required this.contentColor,
    super.key,
  });

  final String value;
  final String label;
  final Color containerColor;
  final Color contentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: contentColor.withValues(alpha: .85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: contentColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
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
    final colors = Theme.of(context).colorScheme;
    final hasLongestSession = snapshot.longestSession > Duration.zero;
    final hasActiveDay = snapshot.mostActiveDayDuration > Duration.zero;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Card(
        key: const ValueKey('stats-listening-habits-card'),
        color: colors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Listening habits',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              _HabitMetric(
                icon: Icons.history_rounded,
                label: 'Total sessions',
                value: '${snapshot.sessionCount}',
              ),
              const SizedBox(height: 16),
              _HabitMetric(
                icon: Icons.hearing_rounded,
                label: 'Average session',
                value: _formatDuration(snapshot.averageSession),
              ),
              const SizedBox(height: 16),
              _HabitMetric(
                icon: Icons.bolt_rounded,
                label: 'Longest session',
                value: hasLongestSession
                    ? _formatDuration(snapshot.longestSession)
                    : '—',
              ),
              const SizedBox(height: 16),
              _HabitMetric(
                icon: Icons.auto_graph_rounded,
                label: 'Sessions per day',
                value: snapshot.sessionsPerDay.toStringAsFixed(1),
              ),
              const SizedBox(height: 20),
              Divider(color: colors.outlineVariant.withValues(alpha: .3)),
              const SizedBox(height: 20),
              _Highlight(
                icon: Icons.calendar_month_rounded,
                title: 'Most active day',
                value: hasActiveDay ? snapshot.mostActiveDay : '—',
                detail: hasActiveDay
                    ? _formatDuration(snapshot.mostActiveDayDuration)
                    : 'No playback yet',
              ),
              const SizedBox(height: 20),
              _Highlight(
                icon: Icons.auto_graph_rounded,
                title: 'Peak timeline slot',
                value: snapshot.peakWindow == 'No data'
                    ? '—'
                    : snapshot.peakWindow,
                detail: snapshot.sessionCount == 0
                    ? 'No playback yet'
                    : 'Your favorite listening window',
              ),
            ],
          ),
        ),
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

class _HabitMetric extends StatelessWidget {
  const _HabitMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: colors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                detail,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.snapshot,
    required this.range,
    required this.metric,
    required this.onMetricChanged,
  });

  final PlaybackStatsSnapshot snapshot;
  final _StatsRange range;
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
    final hasTimeline = values.any((value) => value > 0);
    final rangeTitle = switch (range) {
      _StatsRange.day => 'Daily rhythm',
      _StatsRange.week => 'Weekly rhythm',
      _StatsRange.month => 'Monthly rhythm',
      _StatsRange.year => 'Yearly rhythm',
      _StatsRange.all => 'All-time rhythm',
    };
    final groupedLabel = switch (range) {
      _StatsRange.day => 'Grouped into 4-hour windows',
      _StatsRange.week => 'Grouped by day of week',
      _StatsRange.month => 'Grouped by week of month',
      _StatsRange.year => 'Grouped by month',
      _StatsRange.all => 'Grouped by year',
    };
    final cardColor = switch (range) {
      _StatsRange.day ||
      _StatsRange.week => colors.primaryContainer.withValues(alpha: .45),
      _StatsRange.month ||
      _StatsRange.year => colors.secondaryContainer.withValues(alpha: .42),
      _StatsRange.all => colors.tertiaryContainer.withValues(alpha: .4),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Listening timeline',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  switch (metric) {
                    _TimelineMetric.listeningTime =>
                      'Total listening captured in the selected range.',
                    _TimelineMetric.playCount =>
                      'How many sessions you completed per segment.',
                    _TimelineMetric.averagePlay =>
                      'Average listening length for each segment.',
                  },
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in _TimelineMetric.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _StatsFilterChip(
                      selected: metric == item,
                      selectedColor: colors.primary,
                      selectedContentColor: colors.onPrimary,
                      onSelected: () => onMetricChanged(item),
                      label: switch (item) {
                        _TimelineMetric.listeningTime => 'Listening time',
                        _TimelineMetric.playCount => 'Play count',
                        _TimelineMetric.averagePlay => 'Average session',
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!hasTimeline)
            const _StatsEmptyState(
              icon: Icons.play_circle_outline_rounded,
              title: 'No listening data yet',
              subtitle: 'Press play to start building your listening timeline',
            )
          else ...[
            Card(
              key: const ValueKey('stats-timeline-chart-card'),
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rangeTitle,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  groupedLabel,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          _TimelineMetricBadge(metric: metric),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      _timelineValueLabel(
                                        metric,
                                        values[index],
                                      ),
                                      maxLines: 1,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: FractionallySizedBox(
                                          heightFactor:
                                              values[index] / maxValue,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: index == peakIndex
                                                  ? colors.primary
                                                  : colors.secondaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      const [
                                        'M',
                                        'T',
                                        'W',
                                        'T',
                                        'F',
                                        'S',
                                        'S',
                                      ][index],
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
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
              ),
            ),
            const SizedBox(height: 16),
            _Highlight(
              icon: Icons.auto_graph_rounded,
              title: 'Peak segment',
              value: const [
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
                'Sunday',
              ][peakIndex],
              detail: _timelineValueLabel(metric, values[peakIndex]),
            ),
          ],
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

class _TimelineMetricBadge extends StatelessWidget {
  const _TimelineMetricBadge({required this.metric});

  final _TimelineMetric metric;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (metric) {
      _TimelineMetric.listeningTime => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      _TimelineMetric.playCount => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      _TimelineMetric.averagePlay => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        switch (metric) {
          _TimelineMetric.listeningTime => 'Listening time',
          _TimelineMetric.playCount => 'Play count',
          _TimelineMetric.averagePlay => 'Average session',
        },
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatsFilterChip extends StatelessWidget {
  const _StatsFilterChip({
    required this.selected,
    required this.selectedColor,
    required this.selectedContentColor,
    required this.onSelected,
    required this.label,
  });

  final bool selected;
  final Color selectedColor;
  final Color selectedContentColor;
  final VoidCallback onSelected;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      backgroundColor: colors.surfaceContainer,
      selectedColor: selectedColor,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected ? selectedContentColor : colors.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
      ),
      label: Text(label),
    );
  }
}

class _StatsEmptyState extends StatelessWidget {
  const _StatsEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          ClipPath(
            clipper: const RoundedStarClipper(sides: 8, curve: .1),
            child: Container(
              width: 72,
              height: 72,
              color: colors.primaryContainer,
              alignment: Alignment.center,
              child: Icon(icon, size: 32, color: colors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
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
    final colors = Theme.of(context).colorScheme;
    final maximum = values.fold<double>(
      1,
      (largest, entry) =>
          entry.durationMs > largest ? entry.durationMs : largest,
    );
    final palette = switch (dimension) {
      _CategoryDimension.genre => (
        container: colors.tertiaryContainer,
        content: colors.onTertiaryContainer,
        accent: colors.tertiary,
        onAccent: colors.onTertiary,
      ),
      _CategoryDimension.artist => (
        container: colors.primaryContainer,
        content: colors.onPrimaryContainer,
        accent: colors.primary,
        onAccent: colors.onPrimary,
      ),
      _CategoryDimension.album => (
        container: colors.secondaryContainer,
        content: colors.onSecondaryContainer,
        accent: colors.secondary,
        onAccent: colors.onSecondary,
      ),
      _CategoryDimension.song => (
        container: colors.surfaceContainerHigh,
        content: colors.onSurface,
        accent: colors.primary,
        onAccent: colors.onPrimary,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top categories',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Compare how you listen across genres, artists, albums, and songs.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in _CategoryDimension.values.reversed)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _StatsFilterChip(
                      selected: dimension == item,
                      selectedColor: switch (item) {
                        _CategoryDimension.genre => colors.tertiary,
                        _CategoryDimension.artist => colors.primary,
                        _CategoryDimension.album => colors.secondary,
                        _CategoryDimension.song => colors.primary,
                      },
                      selectedContentColor: switch (item) {
                        _CategoryDimension.genre => colors.onTertiary,
                        _CategoryDimension.artist => colors.onPrimary,
                        _CategoryDimension.album => colors.onSecondary,
                        _CategoryDimension.song => colors.onPrimary,
                      },
                      onSelected: () => onDimensionChanged(item),
                      label: switch (item) {
                        _CategoryDimension.genre => 'Genre',
                        _CategoryDimension.artist => 'Artist',
                        _CategoryDimension.album => 'Album',
                        _CategoryDimension.song => 'Song',
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (values.isEmpty)
            const _StatsEmptyState(
              icon: Icons.music_note_rounded,
              title: 'No category data yet',
              subtitle: 'Press play to surface your listening highlights',
            )
          else
            Card(
              key: const ValueKey('stats-category-chart-card'),
              color: palette.container,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      switch (dimension) {
                        _CategoryDimension.genre => 'Listening by genre',
                        _CategoryDimension.artist => 'Listening by artist',
                        _CategoryDimension.album => 'Listening by album',
                        _CategoryDimension.song => 'Listening by song',
                      },
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: palette.content),
                    ),
                    const SizedBox(height: 20),
                    for (var index = 0; index < values.length; index++) ...[
                      _CategoryMetricRow(
                        rank: index + 1,
                        entry: values[index],
                        progress: values[index].durationMs / maximum,
                        contentColor: palette.content,
                        accentColor: palette.accent,
                        accentContentColor: palette.onAccent,
                      ),
                      if (index != values.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_CategoryEntry> _entries(AppController controller) {
    if (dimension == _CategoryDimension.genre) {
      return [
        for (final entry in snapshot.genreShares)
          _CategoryEntry(
            label: entry.$1,
            durationMs: entry.$2 * snapshot.listeningTime.inMilliseconds,
            supporting: '${(entry.$2 * snapshot.playCount).round()} plays',
          ),
      ];
    }
    if (dimension == _CategoryDimension.artist) {
      final entries = [
        for (final artist in controller.artists)
          _CategoryEntry(
            label: artist.name,
            durationMs: artist.songs.fold<double>(
              0,
              (total, song) =>
                  total +
                  (snapshot.songListeningDurations[song.id]?.inMilliseconds ??
                      0),
            ),
            supporting:
                '${artist.songs.fold<int>(0, (total, song) => total + (snapshot.songPlayCounts[song.id] ?? 0))} plays'
                ' • ${artist.songs.where((song) => snapshot.songPlayCounts.containsKey(song.id)).length} tracks',
          ),
      ]..removeWhere((entry) => entry.durationMs <= 0);
      entries.sort((a, b) => b.durationMs.compareTo(a.durationMs));
      return entries.take(5).toList(growable: false);
    }
    if (dimension == _CategoryDimension.album) {
      final entries = [
        for (final album in controller.albums)
          _CategoryEntry(
            label: album.title,
            durationMs: album.songs.fold<double>(
              0,
              (total, song) =>
                  total +
                  (snapshot.songListeningDurations[song.id]?.inMilliseconds ??
                      0),
            ),
            supporting:
                '${album.songs.fold<int>(0, (total, song) => total + (snapshot.songPlayCounts[song.id] ?? 0))} plays'
                ' • ${album.songs.where((song) => snapshot.songPlayCounts.containsKey(song.id)).length} tracks',
          ),
      ]..removeWhere((entry) => entry.durationMs <= 0);
      entries.sort((a, b) => b.durationMs.compareTo(a.durationMs));
      return entries.take(5).toList(growable: false);
    }
    final songsById = {for (final song in controller.songs) song.id: song};
    final entries = [
      for (final entry in snapshot.songListeningDurations.entries)
        if (songsById[entry.key] case final song?)
          _CategoryEntry(
            label: song.title,
            durationMs: entry.value.inMilliseconds.toDouble(),
            supporting:
                '${snapshot.songPlayCounts[entry.key] ?? 0} plays'
                '${song.artist.trim().isEmpty ? '' : ' • ${song.artist}'}',
          ),
    ]..sort((a, b) => b.durationMs.compareTo(a.durationMs));
    return entries.take(5).toList(growable: false);
  }
}

class _CategoryEntry {
  const _CategoryEntry({
    required this.label,
    required this.durationMs,
    required this.supporting,
  });

  final String label;
  final double durationMs;
  final String supporting;
}

class _CategoryMetricRow extends StatelessWidget {
  const _CategoryMetricRow({
    required this.rank,
    required this.entry,
    required this.progress,
    required this.contentColor,
    required this.accentColor,
    required this.accentContentColor,
  });

  final int rank;
  final _CategoryEntry entry;
  final double progress;
  final Color contentColor;
  final Color accentColor;
  final Color accentContentColor;

  @override
  Widget build(BuildContext context) {
    final highlighted = rank == 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted
            ? accentColor.withValues(alpha: .16)
            : contentColor.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: highlighted
                      ? accentColor
                      : accentColor.withValues(alpha: .24),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$rank',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: highlighted ? accentContentColor : accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: contentColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.supporting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: contentColor.withValues(alpha: .76),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatStatsDuration(
                  Duration(milliseconds: entry.durationMs.round()),
                ),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: contentColor,
                  fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
            color: highlighted
                ? accentColor
                : accentColor.withValues(alpha: .74),
            backgroundColor: contentColor.withValues(alpha: .18),
          ),
        ],
      ),
    );
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
        final bDuration = b.songs.fold<int>(
          0,
          (total, song) =>
              total +
              (snapshot.songListeningDurations[song.id]?.inMilliseconds ?? 0),
        );
        final aDuration = a.songs.fold<int>(
          0,
          (total, song) =>
              total +
              (snapshot.songListeningDurations[song.id]?.inMilliseconds ?? 0),
        );
        return bDuration.compareTo(aDuration);
      })
      ..removeWhere(
        (artist) => artist.songs.every(
          (song) =>
              (snapshot.songListeningDurations[song.id] ?? Duration.zero) ==
              Duration.zero,
        ),
      );
    final visible = artists.take(5).toList(growable: false);
    final colors = Theme.of(context).colorScheme;
    final contentColor = colors.onSecondaryContainer;
    final maximum = visible.fold<int>(1, (largest, artist) {
      final duration = _artistDurationMs(artist.songs);
      return duration > largest ? duration : largest;
    });
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Card(
        key: const ValueKey('stats-top-artists-card'),
        color: colors.secondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top artists',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: contentColor),
              ),
              const SizedBox(height: 20),
              if (visible.isEmpty) ...[
                const _StatsEmptyState(
                  icon: Icons.music_note_rounded,
                  title: 'No top artists yet',
                  subtitle:
                      'Your top artists will appear after you start listening',
                ),
              ] else ...[
                for (var index = 0; index < visible.length; index++) ...[
                  _RankedStatsRow(
                    leading: _ArtistInitialsAvatar(name: visible[index].name),
                    title: '#${index + 1} ${visible[index].name}',
                    supporting:
                        '${_artistPlayCount(visible[index].songs)} plays'
                        ' • ${_artistTrackCount(visible[index].songs)} tracks',
                    duration: Duration(
                      milliseconds: _artistDurationMs(visible[index].songs),
                    ),
                    progress: _artistDurationMs(visible[index].songs) / maximum,
                    contentColor: contentColor,
                    progressColor: colors.secondary,
                  ),
                  if (index != visible.length - 1) const SizedBox(height: 16),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _artistDurationMs(Iterable<Song> songs) => songs.fold<int>(
    0,
    (total, song) =>
        total + (snapshot.songListeningDurations[song.id]?.inMilliseconds ?? 0),
  );

  int _artistPlayCount(Iterable<Song> songs) => songs.fold<int>(
    0,
    (total, song) => total + (snapshot.songPlayCounts[song.id] ?? 0),
  );

  int _artistTrackCount(Iterable<Song> songs) => songs
      .where((song) => snapshot.songPlayCounts.containsKey(song.id))
      .length;
}

class _ArtistInitialsAvatar extends StatelessWidget {
  const _ArtistInitialsAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: .18),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '—' : initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: colors.secondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _RankedStatsRow extends StatelessWidget {
  const _RankedStatsRow({
    required this.leading,
    required this.title,
    required this.supporting,
    required this.duration,
    required this.progress,
    required this.contentColor,
    required this.progressColor,
  });

  final Widget leading;
  final String title;
  final String supporting;
  final Duration duration;
  final double progress;
  final Color contentColor;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            leading,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: contentColor),
                  ),
                  Text(
                    supporting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: contentColor.withValues(alpha: .76),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatStatsDuration(duration),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: contentColor.withValues(alpha: .76),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress.clamp(0, 1),
          color: progressColor,
          backgroundColor: contentColor.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(99),
        ),
      ],
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
        return _albumDurationMs(b.songs).compareTo(_albumDurationMs(a.songs));
      })
      ..removeWhere((album) => _albumDurationMs(album.songs) <= 0);
    final visible = albums.take(5).toList(growable: false);
    final colors = Theme.of(context).colorScheme;
    final contentColor = colors.onTertiaryContainer;
    final maximum = visible.fold<int>(1, (largest, album) {
      final duration = _albumDurationMs(album.songs);
      return duration > largest ? duration : largest;
    });
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Card(
        key: const ValueKey('stats-top-albums-card'),
        color: colors.tertiaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top albums',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: contentColor),
              ),
              const SizedBox(height: 20),
              if (visible.isEmpty) ...[
                const _StatsEmptyState(
                  icon: Icons.album_rounded,
                  title: 'No top albums yet',
                  subtitle:
                      'Your top albums will appear after you start listening',
                ),
              ] else ...[
                for (var index = 0; index < visible.length; index++) ...[
                  _RankedStatsRow(
                    leading: Artwork(
                      colors: visible[index].colors,
                      size: 56,
                      borderRadius: 16,
                      mediaStoreId: visible[index].songs.first.mediaStoreId,
                    ),
                    title: '#${index + 1} ${visible[index].title}',
                    supporting:
                        '${_albumPlayCount(visible[index].songs)} plays'
                        ' • ${_albumTrackCount(visible[index].songs)} tracks',
                    duration: Duration(
                      milliseconds: _albumDurationMs(visible[index].songs),
                    ),
                    progress: _albumDurationMs(visible[index].songs) / maximum,
                    contentColor: contentColor,
                    progressColor: colors.tertiary,
                  ),
                  if (index != visible.length - 1) const SizedBox(height: 16),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _albumDurationMs(Iterable<Song> songs) => songs.fold<int>(
    0,
    (total, song) =>
        total + (snapshot.songListeningDurations[song.id]?.inMilliseconds ?? 0),
  );

  int _albumPlayCount(Iterable<Song> songs) => songs.fold<int>(
    0,
    (total, song) => total + (snapshot.songPlayCounts[song.id] ?? 0),
  );

  int _albumTrackCount(Iterable<Song> songs) => songs
      .where((song) => snapshot.songPlayCounts.containsKey(song.id))
      .length;
}

class _TrackConcentration extends StatelessWidget {
  const _TrackConcentration({required this.snapshot});

  final PlaybackStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final durations =
        snapshot.songListeningDurations.values
            .where((duration) => duration > Duration.zero)
            .map((duration) => duration.inMilliseconds)
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final totalDuration = durations.fold<int>(
      0,
      (total, duration) => total + duration,
    );
    final topOneDuration = durations.isEmpty ? 0 : durations.first;
    final topThreeDuration = durations
        .take(3)
        .fold<int>(0, (total, duration) => total + duration);
    final topThreeShare = totalDuration == 0
        ? 0.0
        : topThreeDuration / totalDuration;
    final averagePlays = durations.isEmpty
        ? 0.0
        : snapshot.playCount / durations.length;
    final slices = <_TrackShareSlice>[
      if (topOneDuration > 0)
        _TrackShareSlice(
          label: 'Top 1',
          durationMs: topOneDuration,
          color: colors.primary,
        ),
      if (topThreeDuration - topOneDuration > 0)
        _TrackShareSlice(
          label: 'Top 2–3',
          durationMs: topThreeDuration - topOneDuration,
          color: colors.secondary,
        ),
      if (totalDuration - topThreeDuration > 0)
        _TrackShareSlice(
          label: 'Others',
          durationMs: totalDuration - topThreeDuration,
          color: colors.tertiary,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Card(
        key: const ValueKey('stats-track-concentration-card'),
        color: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Track concentration',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'How focused or varied your listening was',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: .78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (durations.isEmpty)
                const _StatsEmptyState(
                  icon: Icons.auto_graph_rounded,
                  title: 'No listening concentration yet',
                  subtitle:
                      'Track distribution appears after you start listening',
                )
              else
                _TrackDistributionOverview(
                  slices: slices,
                  totalDurationMs: totalDuration,
                  topThreeShare: topThreeShare,
                  averagePlaysPerTrack: averagePlays,
                  uniqueTracks: durations.length,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackShareSlice {
  const _TrackShareSlice({
    required this.label,
    required this.durationMs,
    required this.color,
  });

  final String label;
  final int durationMs;
  final Color color;
}

class _TrackDistributionOverview extends StatelessWidget {
  const _TrackDistributionOverview({
    required this.slices,
    required this.totalDurationMs,
    required this.topThreeShare,
    required this.averagePlaysPerTrack,
    required this.uniqueTracks,
  });

  final List<_TrackShareSlice> slices;
  final int totalDurationMs;
  final double topThreeShare;
  final double averagePlaysPerTrack;
  final int uniqueTracks;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stats = _TrackDistributionStats(
      topThreeShare: topThreeShare,
      averagePlaysPerTrack: averagePlaysPerTrack,
      uniqueTracks: uniqueTracks,
    );
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(26),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final donut = _TrackDistributionDonut(
                slices: slices,
                totalDurationMs: totalDurationMs,
                topThreeShare: topThreeShare,
              );
              if (constraints.maxWidth < 420) {
                return Column(
                  children: [donut, const SizedBox(height: 12), stats],
                );
              }
              return Row(
                children: [
                  donut,
                  const SizedBox(width: 14),
                  Expanded(child: stats),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < slices.length; index++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: slices[index].color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    slices[index].label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '${(slices[index].durationMs / totalDurationMs * 100).round()}%',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(width: 10),
                Text(
                  _formatStatsDuration(
                    Duration(milliseconds: slices[index].durationMs),
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (index != slices.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TrackDistributionStats extends StatelessWidget {
  const _TrackDistributionStats({
    required this.topThreeShare,
    required this.averagePlaysPerTrack,
    required this.uniqueTracks,
  });

  final double topThreeShare;
  final double averagePlaysPerTrack;
  final int uniqueTracks;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Listening concentration',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        Text(
          'Top 3 tracks make up ${(topThreeShare * 100).round()}% of your listening',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TrackSummaryMetric(
                value: averagePlaysPerTrack.toStringAsFixed(1),
                label: 'Avg plays / track',
                background: colors.primaryContainer.withValues(alpha: .55),
                foreground: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TrackSummaryMetric(
                value: '$uniqueTracks',
                label: 'Unique tracks',
                background: colors.secondaryContainer.withValues(alpha: .52),
                foreground: colors.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrackSummaryMetric extends StatelessWidget {
  const _TrackSummaryMetric({
    required this.value,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String value;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground.withValues(alpha: .76),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackDistributionDonut extends StatelessWidget {
  const _TrackDistributionDonut({
    required this.slices,
    required this.totalDurationMs,
    required this.topThreeShare,
  });

  final List<_TrackShareSlice> slices;
  final int totalDurationMs;
  final double topThreeShare;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 158,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(158),
            painter: _TrackDistributionPainter(
              slices: slices,
              totalDurationMs: totalDurationMs,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(topThreeShare * 100).round()}%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('top 3', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackDistributionPainter extends CustomPainter {
  const _TrackDistributionPainter({
    required this.slices,
    required this.totalDurationMs,
  });

  final List<_TrackShareSlice> slices;
  final int totalDurationMs;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 18.0;
    const fullCircle = 6.283185307179586;
    const gapRadians = .08;
    final rect = Rect.fromLTWH(
      strokeWidth / 2 + 8,
      strokeWidth / 2 + 8,
      size.width - strokeWidth - 16,
      size.height - strokeWidth - 16,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    var start = -1.5707963267948966;
    for (final slice in slices) {
      final rawSweep = slice.durationMs / totalDurationMs * fullCircle;
      paint.color = slice.color;
      canvas.drawArc(
        rect,
        start + gapRadians / 2,
        (rawSweep - gapRadians).clamp(0, fullCircle),
        false,
        paint,
      );
      start += rawSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _TrackDistributionPainter oldDelegate) =>
      oldDelegate.slices != slices ||
      oldDelegate.totalDurationMs != totalDurationMs;
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
        (song) =>
            (widget.snapshot.songListeningDurations[song.id] ??
                Duration.zero) ==
            Duration.zero,
      )
      ..sort(
        (a, b) =>
            (widget.snapshot.songListeningDurations[b.id] ?? Duration.zero)
                .compareTo(
                  widget.snapshot.songListeningDurations[a.id] ?? Duration.zero,
                ),
      );
    final visible = showAll ? songs : songs.take(8).toList(growable: false);
    final maximumDuration = songs.fold<int>(1, (largest, song) {
      final duration =
          widget.snapshot.songListeningDurations[song.id]?.inMilliseconds ?? 0;
      return duration > largest ? duration : largest;
    });
    return _StatsCard(
      title: 'Tracks in this range',
      subtitle: 'Most played tracks for the selected time range.',
      child: songs.isEmpty
          ? const _StatsEmptyState(
              icon: Icons.music_note_rounded,
              title: 'No top tracks',
              subtitle:
                  'Listen to your favorites to see them highlighted here.',
            )
          : Column(
              children: [
                for (var index = 0; index < visible.length; index++) ...[
                  _SongStatsRow(
                    rank: index + 1,
                    song: visible[index],
                    playCount:
                        widget.snapshot.songPlayCounts[visible[index].id] ?? 0,
                    duration:
                        widget.snapshot.songListeningDurations[visible[index]
                            .id] ??
                        Duration.zero,
                    maximumDurationMs: maximumDuration,
                  ),
                  if (index != visible.length - 1) const SizedBox(height: 12),
                ],
                if (songs.length > 8) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => setState(() => showAll = !showAll),
                      style: TextButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        showAll ? 'Collapse tracks' : 'Show all tracks',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _SongStatsRow extends StatelessWidget {
  const _SongStatsRow({
    required this.rank,
    required this.song,
    required this.playCount,
    required this.duration,
    required this.maximumDurationMs,
  });

  final int rank;
  final Song song;
  final int playCount;
  final Duration duration;
  final int maximumDurationMs;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (accent, onAccent, background) = switch (rank) {
      1 => (
        colors.primary,
        colors.onPrimary,
        colors.primaryContainer.withValues(alpha: .45),
      ),
      2 || 3 => (
        colors.secondary,
        colors.onSecondary,
        colors.secondaryContainer.withValues(alpha: .36),
      ),
      _ => (colors.tertiary, colors.onTertiary, colors.surfaceContainerLow),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: rank == 1 ? accent : accent.withValues(alpha: .24),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$rank',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: rank == 1 ? onAccent : accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Artwork(
                colors: song.colors,
                size: 52,
                borderRadius: 14,
                mediaStoreId: song.mediaStoreId,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '$playCount plays',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatStatsDuration(duration),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: duration.inMilliseconds / maximumDurationMs,
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
            color: accent,
            backgroundColor: colors.onSurfaceVariant.withValues(alpha: .2),
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Card(
        color: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
