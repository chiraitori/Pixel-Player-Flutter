import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/pixelplay_theme.dart';
import '../../core/theme/rounded_star_clipper.dart';
import '../../features/player/full_player.dart';
import '../../features/player/mini_player.dart';
import '../../shared/widgets/artwork.dart';

class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({required this.albumId, super.key});

  final String albumId;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final matches = controller.albums.where(
      (album) => album.id == albumId || album.title == albumId,
    );
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Album not found')),
      );
    }

    final album = matches.first;
    final brightness = Theme.of(context).brightness;
    final scheme = ColorScheme.fromSeed(
      seedColor: album.colors.first,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      contrastLevel: .05,
    );
    return Theme(
      data: PixelPlayTheme.fromColorScheme(scheme),
      child: _AlbumDetailBody(album: album),
    );
  }
}

class _AlbumDetailBody extends StatelessWidget {
  const _AlbumDetailBody({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final songs = album.songs;
    final grouped = <int, List<Song>>{};
    for (final song in songs) {
      grouped.putIfAbsent(song.disc, () => <Song>[]).add(song);
    }
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
    final miniVisible = controller.currentSong != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motionDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightnessOverlay(Theme.of(context).brightness),
      child: PopScope(
        canPop: !controller.fullPlayerVisible,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && controller.fullPlayerVisible) {
            controller.hideFullPlayer();
          }
        },
        child: Scaffold(
          backgroundColor: colors.surface,
          body: Stack(
            children: [
              CustomScrollView(
                key: const ValueKey('album-detail-scroll'),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _AlbumHeaderDelegate(
                      album: album,
                      songCount: songs.length,
                      minHeight: MediaQuery.paddingOf(context).top + 64,
                      onBack: () => Navigator.pop(context),
                      onShuffle: songs.isEmpty
                          ? null
                          : () => controller.playShuffled(songs),
                    ),
                  ),
                  if (songs.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No songs in this album')),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        systemBottom +
                            (miniVisible
                                ? miniPlayerHeight + miniPlayerBottomSpacer
                                : 0) +
                            96,
                      ),
                      sliver: SliverList.list(
                        children: [
                          for (final entry in grouped.entries) ...[
                            if (grouped.length > 1)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                                child: Text(
                                  'Disc ${entry.key}',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            for (final song in entry.value)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _AlbumSongTile(song: song, queue: songs),
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
              if (miniVisible && !controller.fullPlayerVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: systemBottom,
                  child: const MiniPlayer(
                    key: ValueKey('album-detail-mini-player'),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !controller.fullPlayerVisible,
                  child: AnimatedSlide(
                    duration: motionDuration,
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
      ),
    );
  }

  static SystemUiOverlayStyle brightnessOverlay(Brightness brightness) =>
      brightness == Brightness.dark
      ? SystemUiOverlayStyle.light
      : SystemUiOverlayStyle.dark;
}

class _AlbumHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _AlbumHeaderDelegate({
    required this.album,
    required this.songCount,
    required this.minHeight,
    required this.onBack,
    required this.onShuffle,
  });

  final Album album;
  final int songCount;
  final double minHeight;
  final VoidCallback onBack;
  final VoidCallback? onShuffle;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => 300;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = Theme.of(context).colorScheme;
    final fraction = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedAlpha = 1 - (fraction * 2).clamp(0.0, 1.0);
    final statusTop = MediaQuery.paddingOf(context).top;
    final titleSize = 30 - 12 * fraction;
    final titleLeft = 24 + 44 * fraction;
    final titleBottom = 20 - 2 * fraction;

    return ColoredBox(
      color: colors.surface,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          if (expandedAlpha > .01)
            Opacity(
              opacity: expandedAlpha,
              child: Artwork(
                colors: album.colors,
                width: double.infinity,
                height: maxExtent,
                borderRadius: 0,
                mediaStoreId: album.songs.first.mediaStoreId,
              ),
            ),
          if (expandedAlpha > .01)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, .42, .77, 1],
                  colors: [
                    Colors.transparent,
                    colors.surface.withValues(alpha: .22 * expandedAlpha),
                    colors.surface.withValues(alpha: .82 * expandedAlpha),
                    colors.surface,
                  ],
                ),
              ),
            ),
          Positioned(
            left: 16,
            top: statusTop + 8,
            child: SizedBox.square(
              dimension: 48,
              child: IconButton.filled(
                key: const ValueKey('album-detail-back'),
                onPressed: onBack,
                style: IconButton.styleFrom(
                  backgroundColor: Color.lerp(
                    colors.surfaceContainerHighest,
                    Colors.transparent,
                    fraction,
                  ),
                  foregroundColor: colors.onSurface,
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 28),
              ),
            ),
          ),
          Positioned(
            left: titleLeft,
            right: 112 - 88 * fraction,
            bottom: titleBottom,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  album.title,
                  maxLines: fraction < .5 ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: titleSize,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.4,
                  ),
                ),
                if (fraction < .96)
                  Opacity(
                    opacity: 1 - fraction * .35,
                    child: Text(
                      '${album.artist} • $songCount ${songCount == 1 ? 'Song' : 'Songs'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (expandedAlpha > .01)
            Positioned(
              right: 12,
              bottom: 8,
              child: Transform.scale(
                scale: expandedAlpha,
                child: SizedBox.square(
                  key: const ValueKey('album-shuffle-star'),
                  dimension: 92,
                  child: ClipPath(
                    clipper: const RoundedStarClipper(sides: 8, curve: .05),
                    child: Material(
                      color: colors.primaryContainer,
                      child: InkWell(
                        onTap: onShuffle,
                        child: Center(
                          child: Icon(
                            Icons.shuffle_rounded,
                            size: 32,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AlbumHeaderDelegate oldDelegate) =>
      album != oldDelegate.album ||
      songCount != oldDelegate.songCount ||
      minHeight != oldDelegate.minHeight ||
      onShuffle != oldDelegate.onShuffle;
}

class _AlbumSongTile extends StatelessWidget {
  const _AlbumSongTile({required this.song, required this.queue});

  final Song song;
  final List<Song> queue;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final current = controller.currentSong?.id == song.id;
    return Material(
      color: current ? colors.primaryContainer : colors.surfaceContainerLow,
      borderRadius: current
          ? BorderRadius.circular(36)
          : BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => controller.playSong(song, fromQueue: queue),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: current
                                  ? colors.onPrimaryContainer
                                  : colors.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color:
                              (current
                                      ? colors.onPrimaryContainer
                                      : colors.onSurfaceVariant)
                                  .withValues(alpha: .78),
                        ),
                      ),
                    ],
                  ),
                ),
                if (current)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      controller.isPlaying
                          ? Icons.graphic_eq_rounded
                          : Icons.pause_rounded,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                SizedBox.square(
                  dimension: 48,
                  child: IconButton.filled(
                    onPressed: () => _showSongOptions(context),
                    style: IconButton.styleFrom(
                      backgroundColor: current
                          ? colors.onPrimaryContainer
                          : colors.surfaceContainerHigh,
                      foregroundColor: current
                          ? colors.primaryContainer
                          : colors.onSurface,
                    ),
                    icon: const Icon(Icons.more_vert_rounded, size: 26),
                    tooltip: 'More options for ${song.title}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSongOptions(BuildContext context) {
    final controller = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Artwork(
                  colors: song.colors,
                  mediaStoreId: song.mediaStoreId,
                  size: 48,
                  borderRadius: 10,
                ),
                title: Text(song.title),
                subtitle: Text(song.artist),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('Play'),
                onTap: () {
                  Navigator.pop(context);
                  controller.playSong(song, fromQueue: queue);
                },
              ),
              ListTile(
                leading: Icon(
                  controller.isFavorite(song)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                title: Text(
                  controller.isFavorite(song)
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                ),
                onTap: () {
                  Navigator.pop(context);
                  controller.toggleFavoriteFor(song);
                },
              ),
              ListTile(
                leading: Icon(Icons.playlist_play_rounded),
                title: Text('Play next'),
                onTap: () {
                  Navigator.pop(context);
                  controller.addSongNextToQueue(song);
                },
              ),
              ListTile(
                leading: Icon(Icons.queue_music_rounded),
                title: Text('Add to queue'),
                onTap: () {
                  Navigator.pop(context);
                  controller.addSongToQueue(song);
                },
              ),
              ListTile(
                leading: Icon(Icons.playlist_add_rounded),
                title: Text('Add to playlist'),
                onTap: () {
                  Navigator.pop(context);
                  _showPlaylistPicker(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Song information'),
                subtitle: Text(
                  '${song.durationLabel} • ${song.year} • Track ${song.track}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlaylistPicker(BuildContext context) {
    final controller = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(
                'Add to playlist',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (controller.playlists.isEmpty)
              const ListTile(title: Text('No playlists yet'))
            else
              for (final playlist in controller.playlists)
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: Text(playlist.name),
                  trailing: playlist.songs.any((item) => item.id == song.id)
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: playlist.songs.any((item) => item.id == song.id)
                      ? null
                      : () {
                          controller.addSongsToPlaylist(playlist.id, [song.id]);
                          Navigator.pop(context);
                        },
                ),
          ],
        ),
      ),
    );
  }
}
