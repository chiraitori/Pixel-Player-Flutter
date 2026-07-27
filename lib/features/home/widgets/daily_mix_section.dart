import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/song.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/rounded_star_clipper.dart';
import '../../../shared/widgets/artwork.dart';
import '../../../shared/widgets/song_tile.dart';

/// Source-parity port of Compose `DailyMixSection`.
class DailyMixSection extends StatelessWidget {
  const DailyMixSection({required this.songs, required this.onOpen, super.key});

  final List<Song> songs;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visibleSongs = songs.take(4).toList(growable: false);
    final headerSongs = songs.take(3).toList(growable: false);

    return Padding(
      // Compose DailyMixSection owns this extra 16 dp top spacer in addition
      // to the LazyColumn's 24 dp item spacing.
      padding: const EdgeInsets.only(left: 16, top: 16, right: 16),
      child: Material(
        color: colors.surfaceContainer,
        elevation: 0,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _DailyMixHeader(songs: headerSongs),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < visibleSongs.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(height: 3),
                      _DailyMixSongRow(song: visibleSongs[index], queue: songs),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Material(
                color: Colors.transparent,
                shape: const RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                    bottomLeft: Radius.circular(60),
                    bottomRight: Radius.circular(60),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpen,
                  child: const SizedBox(
                    height: 48,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Check all of Daily Mix',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyMixHeader extends StatelessWidget {
  const _DailyMixHeader({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.tertiary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SizedBox(
        height: 80,
        child: Padding(
          padding: const EdgeInsets.only(left: 22, right: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY MIX',
                      style: TextStyle(
                        fontFamily: 'GoogleSansFlex',
                        fontSize: 20,
                        height: 22 / 20,
                        fontWeight: FontWeight.normal,
                        letterSpacing: -.35,
                        fontVariations: const [
                          ui.FontVariation('wght', 630),
                          ui.FontVariation('wdth', 136),
                          ui.FontVariation('GRAD', 40),
                          ui.FontVariation('ROND', 100),
                          ui.FontVariation('XTRA', 520),
                          ui.FontVariation('YOPQ', 90),
                          ui.FontVariation('YTLC', 505),
                        ],
                        color: colors.onPrimary,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 1),
                      child: Text(
                        'Based on History',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onPrimary.withValues(alpha: .8),
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 110,
                height: 50,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    for (var index = 0; index < songs.length; index++)
                      Positioned(
                        right: (songs.length - 1 - index) * 30,
                        top: switch (index) {
                          0 => 0,
                          1 => 4,
                          _ => 1,
                        },
                        child: _DailyMixThumbnail(
                          song: songs[index],
                          index: index,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyMixThumbnail extends StatelessWidget {
  const _DailyMixThumbnail({required this.song, required this.index});

  final Song song;
  final int index;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.surface;
    final size = switch (index) {
      0 => 50.0,
      1 => 44.0,
      _ => 48.0,
    };
    final art = Artwork(
      colors: song.colors,
      size: size,
      borderRadius: 0,
      mediaStoreId: song.mediaStoreId,
    );

    return SizedBox.square(
      dimension: size,
      child: switch (index) {
        0 => ClipPath(
          clipper: const RoundedStarClipper(sides: 6, curve: .09, rotation: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(color: borderColor),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ClipPath(
                clipper: const RoundedStarClipper(
                  sides: 6,
                  curve: .09,
                  rotation: 10,
                ),
                child: art,
              ),
            ),
          ),
        ),
        1 => DecoratedBox(
          decoration: BoxDecoration(color: borderColor, shape: BoxShape.circle),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipOval(child: art),
          ),
        ),
        _ => Material(
          color: Colors.transparent,
          shape: RoundedSuperellipseBorder(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: borderColor, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: art,
        ),
      },
    );
  }
}

class _DailyMixSongRow extends StatelessWidget {
  const _DailyMixSongRow({required this.song, required this.queue});

  final Song song;
  final List<Song> queue;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final isCurrent = controller.currentSong?.id == song.id;

    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => controller.playSong(song, fromQueue: queue),
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: isCurrent
                                  ? colors.primary
                                  : colors.onSurface,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      SongTile(song: song, queue: queue).showMenu(context),
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'More options',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
