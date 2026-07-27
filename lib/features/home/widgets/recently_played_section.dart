import 'package:flutter/material.dart';

import '../../../core/models/song.dart';
import '../../../core/state/app_controller.dart';
import '../../../shared/widgets/artwork.dart';

const _pillHeight = 58.0;
const _pillSpacing = 8.0;
const _pillLimit = 10;
const _rowCount = 3;
const _artSize = 38.0;
const _widthSteps = [148.0, 166.0, 184.0, 202.0, 220.0];

/// Source-parity port of Compose `RecentlyPlayedSection`.
class RecentlyPlayedSection extends StatelessWidget {
  const RecentlyPlayedSection({
    required this.songs,
    required this.onOpenAll,
    super.key,
  });

  final List<Song> songs;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final visibleSongs = songs.take(_pillLimit).toList(growable: false);
    if (visibleSongs.length < 4) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final rows = _buildRows(visibleSongs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  'Recently played',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              IconButton.filled(
                onPressed: onOpenAll,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                style: IconButton.styleFrom(
                  minimumSize: const Size(64, 40),
                  maximumSize: const Size(64, 40),
                  backgroundColor: colors.surfaceContainerHigh,
                  foregroundColor: colors.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _pillHeight * _rowCount + _pillSpacing * (_rowCount - 1),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (
                    var rowIndex = 0;
                    rowIndex < rows.length;
                    rowIndex++
                  ) ...[
                    if (rowIndex > 0) const SizedBox(height: _pillSpacing),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (
                          var itemIndex = 0;
                          itemIndex < rows[rowIndex].length;
                          itemIndex++
                        ) ...[
                          if (itemIndex > 0)
                            const SizedBox(width: _pillSpacing),
                          _RecentlyPlayedPill(
                            song: rows[rowIndex][itemIndex],
                            queue: visibleSongs,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<List<Song>> _buildRows(List<Song> visibleSongs) {
    final rows = List.generate(_rowCount, (_) => <Song>[]);
    final base = visibleSongs.length ~/ _rowCount;
    final remainder = visibleSongs.length % _rowCount;
    final targets = [
      base + (remainder > 0 ? 1 : 0),
      base + (remainder > 1 ? 1 : 0),
      base,
    ];

    var itemIndex = 0;
    for (var columnIndex = 0; columnIndex < targets.first; columnIndex++) {
      for (var rowIndex = 0; rowIndex < _rowCount; rowIndex++) {
        if (itemIndex >= visibleSongs.length) break;
        if (columnIndex >= targets[rowIndex]) continue;
        rows[rowIndex].add(visibleSongs[itemIndex++]);
      }
    }
    return rows;
  }
}

class _RecentlyPlayedPill extends StatelessWidget {
  const _RecentlyPlayedPill({required this.song, required this.queue});

  final Song song;
  final List<Song> queue;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final isCurrent = controller.currentSong?.id == song.id;
    final albumScheme = ColorScheme.fromSeed(
      seedColor: song.colors.isEmpty
          ? Theme.of(context).colorScheme.primary
          : song.colors.first,
      brightness: Theme.of(context).brightness,
    );
    final targetRadius = isCurrent ? 14.0 : _pillHeight / 2;

    return AnimatedContainer(
      key: ValueKey(song.id),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      width: _resolvePillWidth(song.title, song.artist),
      height: _pillHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: albumScheme.primaryContainer,
        borderRadius: BorderRadius.circular(targetRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.playSong(song, fromQueue: queue),
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 12),
            child: Row(
              children: [
                Artwork(
                  colors: song.colors,
                  size: _artSize,
                  borderRadius: _artSize / 2,
                  mediaStoreId: song.mediaStoreId,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: albumScheme.onPrimaryContainer,
                            ) ??
                            TextStyle(color: albumScheme.onPrimaryContainer),
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: albumScheme.onPrimaryContainer.withValues(
                                alpha: .8,
                              ),
                            ) ??
                            TextStyle(
                              color: albumScheme.onPrimaryContainer.withValues(
                                alpha: .8,
                              ),
                            ),
                        child: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

  double _resolvePillWidth(String title, String artist) {
    final weighted = title.trim().length + (artist.trim().length * .55);
    final step = switch (weighted) {
      < 18 => 0,
      < 28 => 1,
      < 40 => 2,
      < 54 => 3,
      _ => 4,
    };
    return _widthSteps[step];
  }
}
