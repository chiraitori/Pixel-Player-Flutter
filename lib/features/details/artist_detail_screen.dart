import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/pixelplay_theme.dart';
import '../../core/theme/rounded_star_clipper.dart';
import '../player/full_player.dart';
import '../player/mini_player.dart';
import '../../shared/widgets/artwork.dart';

class ArtistDetailScreen extends StatelessWidget {
  const ArtistDetailScreen({required this.artistId, super.key});

  final String artistId;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final matches = controller.artists.where(
      (artist) => artist.id == artistId || artist.name == artistId,
    );
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Artist not found')),
      );
    }

    final artist = matches.first;
    final scheme = ColorScheme.fromSeed(
      seedColor: artist.colors.first,
      brightness: Theme.of(context).brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      contrastLevel: .05,
    );
    return Theme(
      data: PixelPlayTheme.fromColorScheme(scheme),
      child: _ArtistDetailBody(artist: artist),
    );
  }
}

class _ArtistDetailBody extends StatefulWidget {
  const _ArtistDetailBody({required this.artist});

  final Artist artist;

  @override
  State<_ArtistDetailBody> createState() => _ArtistDetailBodyState();
}

class _ArtistDetailBodyState extends State<_ArtistDetailBody> {
  late final List<_ArtistAlbumSection> _sections;
  late final Map<String, bool> _expanded;

  String get _customImageKey => 'artist_custom_image_${widget.artist.id}';

  @override
  void initState() {
    super.initState();
    _sections = _buildAlbumSections(widget.artist.songs);
    _expanded = {for (final section in _sections) section.key: true};
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final songs = _sections.expand((section) => section.songs).toList();
    final customImage = controller.stringSetting(_customImageKey, '');
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
    final miniVisible = controller.currentSong != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motionDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
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
                key: const ValueKey('artist-detail-scroll'),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ArtistHeaderDelegate(
                      artist: widget.artist,
                      songsCount: songs.length,
                      customImagePath: customImage,
                      minHeight: MediaQuery.paddingOf(context).top + 64,
                      onBack: () => Navigator.pop(context),
                      onShuffle: songs.isEmpty
                          ? null
                          : () => controller.playShuffled(songs),
                      onChangeImage: _pickArtistImage,
                      onClearImage: customImage.isEmpty
                          ? null
                          : _clearArtistImage,
                    ),
                  ),
                  if (_sections.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No songs by this artist')),
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
                          for (
                            var index = 0;
                            index < _sections.length;
                            index++
                          ) ...[
                            _ArtistAlbumHeader(
                              section: _sections[index],
                              expanded: _expanded[_sections[index].key] ?? true,
                              onToggle: () => setState(() {
                                final key = _sections[index].key;
                                _expanded[key] = !(_expanded[key] ?? true);
                              }),
                              onPlay: () {
                                final sectionSongs = _sections[index].songs;
                                if (sectionSongs.isNotEmpty) {
                                  controller.playSong(
                                    sectionSongs.first,
                                    fromQueue: sectionSongs,
                                  );
                                }
                              },
                            ),
                            AnimatedSize(
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: (_expanded[_sections[index].key] ?? true)
                                  ? _ArtistAlbumSongGroup(
                                      section: _sections[index],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            SizedBox(
                              height: index == _sections.length - 1 ? 24 : 16,
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
                    key: ValueKey('artist-detail-mini-player'),
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

  Future<void> _pickArtistImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (!mounted || path == null || path.isEmpty) return;
    AppScope.of(context).setStringSetting(_customImageKey, path);
    setState(() {});
  }

  void _clearArtistImage() {
    AppScope.of(context).setStringSetting(_customImageKey, '');
    setState(() {});
  }
}

class _ArtistHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ArtistHeaderDelegate({
    required this.artist,
    required this.songsCount,
    required this.customImagePath,
    required this.minHeight,
    required this.onBack,
    required this.onShuffle,
    required this.onChangeImage,
    required this.onClearImage,
  });

  final Artist artist;
  final int songsCount;
  final String customImagePath;
  final double minHeight;
  final VoidCallback onBack;
  final VoidCallback? onShuffle;
  final VoidCallback onChangeImage;
  final VoidCallback? onClearImage;

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
              child: _ArtistHeaderImage(
                artist: artist,
                customImagePath: customImagePath,
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
                    colors.surface.withValues(alpha: .24 * expandedAlpha),
                    colors.surface.withValues(alpha: .84 * expandedAlpha),
                    colors.surface,
                  ],
                ),
              ),
            ),
          Positioned(
            left: 12,
            top: statusTop + 4,
            child: SizedBox.square(
              dimension: 48,
              child: IconButton.filled(
                key: const ValueKey('artist-detail-back'),
                onPressed: onBack,
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceContainerLow,
                  foregroundColor: colors.onSurface,
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 28),
              ),
            ),
          ),
          if (fraction < .5)
            Positioned(
              right: 12,
              top: statusTop + 4,
              child: Opacity(
                opacity: 1 - (fraction * 4).clamp(0.0, 1.0),
                child: _ArtistImageMenu(
                  onChangeImage: onChangeImage,
                  onClearImage: onClearImage,
                ),
              ),
            ),
          Positioned(
            left: titleLeft,
            right: 136 - 48 * fraction,
            bottom: titleBottom,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  artist.name,
                  maxLines: fraction < .5 ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: titleSize,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.4,
                  ),
                ),
                Text(
                  '$songsCount ${songsCount == 1 ? 'Song' : 'Songs'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (expandedAlpha > .01)
            Positioned(
              right: 16,
              bottom: 8,
              child: Transform.scale(
                scale: expandedAlpha,
                child: SizedBox.square(
                  key: const ValueKey('artist-shuffle-star'),
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
  bool shouldRebuild(covariant _ArtistHeaderDelegate oldDelegate) =>
      artist != oldDelegate.artist ||
      songsCount != oldDelegate.songsCount ||
      customImagePath != oldDelegate.customImagePath ||
      minHeight != oldDelegate.minHeight;
}

class _ArtistHeaderImage extends StatelessWidget {
  const _ArtistHeaderImage({
    required this.artist,
    required this.customImagePath,
  });

  final Artist artist;
  final String customImagePath;

  @override
  Widget build(BuildContext context) {
    if (customImagePath.isNotEmpty && File(customImagePath).existsSync()) {
      return Image.file(
        File(customImagePath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.medium,
      );
    }
    return Artwork(
      colors: artist.colors,
      width: double.infinity,
      height: double.infinity,
      borderRadius: 0,
      mediaStoreId: artist.songs.first.mediaStoreId,
    );
  }
}

class _ArtistImageMenu extends StatelessWidget {
  const _ArtistImageMenu({
    required this.onChangeImage,
    required this.onClearImage,
  });

  final VoidCallback onChangeImage;
  final VoidCallback? onClearImage;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) => SizedBox.square(
        dimension: 48,
        child: IconButton.filled(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          ),
          icon: const Icon(Icons.edit_rounded),
          tooltip: 'Edit artist image',
        ),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.add_a_photo_rounded),
          onPressed: onChangeImage,
          child: const Text('Change photo'),
        ),
        if (onClearImage != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.delete_rounded),
            onPressed: onClearImage,
            child: const Text('Reset to default'),
          ),
      ],
    );
  }
}

class _ArtistAlbumHeader extends StatelessWidget {
  const _ArtistAlbumHeader({
    required this.section,
    required this.expanded,
    required this.onToggle,
    required this.onPlay,
  });

  final _ArtistAlbumSection section;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final subtitle = [
      if (section.year > 0) '${section.year}',
      '${section.songs.length} ${section.songs.length == 1 ? 'Song' : 'Songs'}',
    ].join(' • ');
    final bottomRadius = expanded ? 0.0 : 24.0;

    return Material(
      color: colors.surfaceContainerLow.withValues(alpha: .5),
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(24),
        bottom: Radius.circular(bottomRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Artwork(
                colors: section.songs.first.colors,
                size: 52,
                borderRadius: 10,
                mediaStoreId: section.songs.first.mediaStoreId,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onPlay,
                style: IconButton.styleFrom(
                  backgroundColor: colors.tertiaryContainer,
                  foregroundColor: colors.onTertiaryContainer,
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                tooltip: 'Play ${section.title}',
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                duration: const Duration(milliseconds: 260),
                turns: expanded ? .5 : 0,
                child: Icon(
                  Icons.expand_more_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistAlbumSongGroup extends StatelessWidget {
  const _ArtistAlbumSongGroup({required this.section});

  final _ArtistAlbumSection section;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow.withValues(alpha: .5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        child: Column(
          children: [
            for (var index = 0; index < section.songs.length; index++) ...[
              if (index > 0) const SizedBox(height: 2),
              _ArtistSongItem(
                song: section.songs[index],
                queue: section.songs,
                index: index,
                count: section.songs.length,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArtistSongItem extends StatelessWidget {
  const _ArtistSongItem({
    required this.song,
    required this.queue,
    required this.index,
    required this.count,
  });

  final Song song;
  final List<Song> queue;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final current = controller.currentSong?.id == song.id;
    final radius = count == 1
        ? const BorderRadius.all(Radius.circular(16))
        : index == 0
        ? const BorderRadius.vertical(top: Radius.circular(16))
        : index == count - 1
        ? const BorderRadius.vertical(bottom: Radius.circular(16))
        : BorderRadius.circular(4);

    return Material(
      color: current ? colors.primaryContainer : colors.surfaceContainerLowest,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => controller.playSong(song, fromQueue: queue),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: current
                      ? Icon(
                          controller.isPlaying
                              ? Icons.graphic_eq_rounded
                              : Icons.pause_rounded,
                          color: colors.primary,
                        )
                      : Text(
                          '${song.track}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                ),
                const SizedBox(width: 10),
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
                                  ? colors.primary
                                  : colors.onSurface,
                              fontWeight: current
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 2),
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
                  onPressed: () => _showSongInfo(context),
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'More options for ${song.title}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSongInfo(BuildContext context) {
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
                subtitle: Text('${song.artist} • ${song.album}'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('Play'),
                onTap: () {
                  Navigator.pop(context);
                  AppScope.of(context).playSong(song, fromQueue: queue);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Song information'),
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
}

class _ArtistAlbumSection {
  const _ArtistAlbumSection({
    required this.albumId,
    required this.title,
    required this.year,
    required this.songs,
  });

  final int albumId;
  final String title;
  final int year;
  final List<Song> songs;

  String get key => 'artist_album_${albumId}_$title';
}

List<_ArtistAlbumSection> _buildAlbumSections(List<Song> songs) {
  final grouped = <(int, String), List<Song>>{};
  for (final song in songs) {
    final title = song.album.trim().isEmpty ? 'Unknown Album' : song.album;
    grouped.putIfAbsent((song.albumId ?? -1, title), () => []).add(song);
  }

  final sections = grouped.entries.map((entry) {
    final sorted = [...entry.value]
      ..sort((left, right) {
        final byDisc = left.disc.compareTo(right.disc);
        if (byDisc != 0) return byDisc;
        final leftTrack = left.track > 0 ? left.track : 0x7fffffff;
        final rightTrack = right.track > 0 ? right.track : 0x7fffffff;
        final byTrack = leftTrack.compareTo(rightTrack);
        if (byTrack != 0) return byTrack;
        return left.title.toLowerCase().compareTo(right.title.toLowerCase());
      });
    final validYears = entry.value
        .map((song) => song.year)
        .where((year) => year > 0);
    return _ArtistAlbumSection(
      albumId: entry.key.$1,
      title: entry.key.$2,
      year: validYears.isEmpty ? 0 : validYears.reduce((a, b) => a > b ? a : b),
      songs: sorted,
    );
  }).toList();

  sections.sort((left, right) {
    if (left.year > 0 && right.year <= 0) return -1;
    if (left.year <= 0 && right.year > 0) return 1;
    if (left.year != right.year) return right.year.compareTo(left.year);
    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  });
  return sections;
}
