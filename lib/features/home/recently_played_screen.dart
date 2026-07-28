import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../player/full_player.dart';
import '../player/mini_player.dart';
import '../../shared/widgets/song_tile.dart';

enum _HistoryRange {
  day('Today'),
  week('Week to Date'),
  month('Month to Date'),
  year('Year to Date'),
  all('All Time');

  const _HistoryRange(this.label);
  final String label;
}

class RecentlyPlayedScreen extends StatefulWidget {
  const RecentlyPlayedScreen({super.key});

  @override
  State<RecentlyPlayedScreen> createState() => _RecentlyPlayedScreenState();
}

class _RecentlyPlayedScreenState extends State<RecentlyPlayedScreen> {
  _HistoryRange _range = _HistoryRange.week;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final songs = controller.recentlyPlayedSongs
        .where((song) {
          final played = controller.lastPlayedFor(song);
          return played == null || _inRange(played, _range);
        })
        .toList(growable: false);
    final groups = _groupSongs(controller, songs);
    final colors = Theme.of(context).colorScheme;
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
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.secondary.withValues(alpha: .24),
                    colors.surface.withValues(alpha: .55),
                    colors.surface,
                  ],
                  stops: const [0, .5, 1],
                ),
              ),
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: _ExpressiveHistoryHeader()),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _HistoryRange.values.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final range = _HistoryRange.values[index];
                          final selected = range == _range;
                          return _HistoryRangeChip(
                            label: range.label,
                            selected: selected,
                            onTap: () => setState(() => _range = range),
                          );
                        },
                      ),
                    ),
                  ),
                  if (songs.isNotEmpty)
                    SliverToBoxAdapter(child: _HistoryActions(songs: songs)),
                  if (songs.isEmpty)
                    SliverToBoxAdapter(child: _EmptyHistory(range: _range))
                  else
                    for (final group in groups) ...[
                      SliverToBoxAdapter(
                        child: _TimestampDivider(
                          label: group.label,
                          hourBucket: group.hourBucket,
                        ),
                      ),
                      SliverList.builder(
                        itemCount: group.songs.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SongTile(
                            song: group.songs[index],
                            queue: songs,
                          ),
                        ),
                      ),
                    ],
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
            ),
            Positioned(
              left: 10,
              top: MediaQuery.paddingOf(context).top + 8,
              child: IconButton.filled(
                key: const ValueKey('recently-played-back'),
                onPressed: () => Navigator.maybePop(context),
                style: IconButton.styleFrom(
                  backgroundColor: colors.surface,
                  foregroundColor: colors.onSurface,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              ),
            ),
            if (miniVisible && !controller.fullPlayerVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: systemBottom,
                child: const MiniPlayer(
                  key: ValueKey('recently-played-mini-player'),
                ),
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

  bool _inRange(DateTime played, _HistoryRange range) {
    final now = DateTime.now();
    final start = switch (range) {
      _HistoryRange.day => DateTime(now.year, now.month, now.day),
      _HistoryRange.week => DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - DateTime.monday),
      ),
      _HistoryRange.month => DateTime(now.year, now.month),
      _HistoryRange.year => DateTime(now.year),
      _HistoryRange.all => DateTime.fromMillisecondsSinceEpoch(0),
    };
    return !played.isBefore(start);
  }

  List<_HistoryGroup> _groupSongs(AppController controller, List<Song> songs) {
    final groups = <String, List<Song>>{};
    final labels = <String, String>{};
    final hours = <String, bool>{};
    final now = DateTime.now();
    for (final song in songs) {
      final played = controller.lastPlayedFor(song) ?? now;
      final String key;
      final String label;
      final bool hour;
      if (_range == _HistoryRange.day) {
        key = '${played.year}-${played.month}-${played.day}-${played.hour}';
        label = '${played.hour.toString().padLeft(2, '0')}:00';
        hour = true;
      } else {
        key = '${played.year}-${played.month}-${played.day}';
        final today = DateTime(now.year, now.month, now.day);
        final date = DateTime(played.year, played.month, played.day);
        final difference = today.difference(date).inDays;
        label = switch (difference) {
          0 => 'Today',
          1 => 'Yesterday',
          _ => _dateLabel(played, includeYear: _range.index >= 3),
        };
        hour = false;
      }
      groups.putIfAbsent(key, () => []).add(song);
      labels[key] = label;
      hours[key] = hour;
    }
    return [
      for (final entry in groups.entries)
        _HistoryGroup(
          label: labels[entry.key]!,
          hourBucket: hours[entry.key]!,
          songs: entry.value,
        ),
    ];
  }

  String _dateLabel(DateTime date, {required bool includeYear}) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final prefix = includeYear ? '' : '${weekdays[date.weekday - 1]}, ';
    final year = includeYear ? ', ${date.year}' : '';
    return '$prefix${months[date.month - 1]} ${date.day}$year';
  }
}

/// Direct Flutter port of `RecentlyPlayedRangeChip`: a 44dp tertiary outlined
/// pill whose History icon expands in only for the selected range.
class _HistoryRangeChip extends StatelessWidget {
  const _HistoryRangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 255);
    final container = selected ? colors.tertiary : Colors.transparent;
    final content = selected ? colors.onTertiary : colors.tertiary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        key: ValueKey('recent-history-range-$label'),
        duration: duration,
        curve: Curves.fastOutSlowIn,
        height: 44,
        decoration: ShapeDecoration(
          color: container,
          shape: StadiumBorder(
            side: BorderSide(color: colors.tertiary, width: 2),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: duration,
                    curve: Curves.fastOutSlowIn,
                    tween: Tween<double>(end: selected ? 1 : 0),
                    builder: (context, progress, child) => SizedBox(
                      width: 26 * progress,
                      child: ClipRect(
                        child: Transform.scale(
                          scale: .82 + progress * .18,
                          child: Opacity(opacity: progress, child: child),
                        ),
                      ),
                    ),
                    child: Icon(
                      Icons.history_outlined,
                      size: 18,
                      color: content,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: content),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpressiveHistoryHeader extends StatelessWidget {
  const _ExpressiveHistoryHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('recently-played-header'),
      height: 190,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.secondary.withValues(alpha: .24),
            colors.primary.withValues(alpha: .10),
            colors.surface.withValues(alpha: .95),
            colors.surface,
          ],
        ),
      ),
      child: Text(
        'Recently Played',
        style: const TextStyle(
          fontFamily: 'GoogleSansFlex',
          fontSize: 34,
          height: 38 / 34,
          fontWeight: FontWeight.w600,
          letterSpacing: -.4,
        ),
      ),
    );
  }
}

class _HistoryActions extends StatelessWidget {
  const _HistoryActions({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    controller.playSong(songs.first, fromQueue: songs),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(52),
                      bottomLeft: Radius.circular(52),
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play latest'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => controller.playShuffled(songs),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      topRight: Radius.circular(52),
                      bottomRight: Radius.circular(52),
                    ),
                  ),
                ),
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('Shuffle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimestampDivider extends StatelessWidget {
  const _TimestampDivider({required this.label, required this.hourBucket});

  final String label;
  final bool hourBucket;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = hourBucket ? colors.primary : colors.secondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0),
                    color.withValues(alpha: .5),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Chip(
            avatar: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            label: Text(label),
            backgroundColor: hourBucket
                ? colors.primaryContainer.withValues(alpha: .78)
                : colors.secondaryContainer.withValues(alpha: .78),
            side: BorderSide.none,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: .5),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.range});

  final _HistoryRange range;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nothing played ${range.label.toLowerCase()}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('Songs you listen to will appear here.'),
          ],
        ),
      ),
    );
  }
}

class _HistoryGroup {
  const _HistoryGroup({
    required this.label,
    required this.hourBucket,
    required this.songs,
  });

  final String label;
  final bool hourBucket;
  final List<Song> songs;
}
