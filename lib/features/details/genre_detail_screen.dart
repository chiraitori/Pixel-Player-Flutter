import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/services/song_metadata_writer.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/genre_theme.dart';
import '../../core/theme/pixelplay_theme.dart';
import '../../features/player/full_player.dart';
import '../../features/player/mini_player.dart';
import '../library/quick_fill_screen.dart';
import '../../shared/widgets/artwork.dart';

enum _GenreSort { artist, album, title }

class GenreDetailScreen extends StatefulWidget {
  const GenreDetailScreen({required this.genreId, super.key});

  final String genreId;

  @override
  State<GenreDetailScreen> createState() => _GenreDetailScreenState();
}

class _GenreDetailScreenState extends State<GenreDetailScreen> {
  _GenreSort _sort = _GenreSort.artist;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final brightness = Theme.of(context).brightness;
    final songs = controller.songs
        .where(
          (song) =>
              song.genre.trim().toLowerCase() ==
              widget.genreId.trim().toLowerCase(),
        )
        .toList(growable: false);
    final title = songs.firstOrNull?.genre.trim().isNotEmpty == true
        ? songs.first.genre.trim()
        : _displayGenre(widget.genreId);
    final normalizedGenreId = widget.genreId.trim().toLowerCase();
    final isUnknownGenre =
        normalizedGenreId == 'unknown' ||
        normalizedGenreId == 'unknown genre' ||
        title.trim().toLowerCase() == 'unknown' ||
        title.trim().toLowerCase() == 'unknown genre';
    final reference = GenreTheme.reference(title, brightness: brightness);
    final genreScheme = GenreTheme.colorScheme(title, brightness: brightness);
    final theme = PixelPlayTheme.fromColorScheme(genreScheme);
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
    final miniVisible = controller.currentSong != null;
    final miniBottom = systemBottom + miniPlayerHeight + miniPlayerBottomSpacer;

    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          final headerMinExtent = MediaQuery.paddingOf(context).top + 58;
          final groups = _buildGroups(songs, _sort);
          final reduceMotion = MediaQuery.disableAnimationsOf(context);
          final motionDuration = reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220);

          return PopScope(
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
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _GenreHeaderDelegate(
                          title: title,
                          minHeight: headerMinExtent,
                          startColor: reference.container,
                          expandedContentColor: reference.onContainer,
                          onBack: () => Navigator.pop(context),
                        ),
                      ),
                      if (songs.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _GenreEmptyState(title: title),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            8,
                            8,
                            8,
                            (miniVisible ? miniBottom : systemBottom) + 148,
                          ),
                          sliver: SliverList.separated(
                            itemCount: groups.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final group = groups[index];
                              return switch (group) {
                                _ArtistGenreGroup() => _ArtistGroupCard(
                                  key: ValueKey(group.key),
                                  group: group,
                                  queue: songs,
                                ),
                                _AlbumGenreGroup() => _AlbumGroupCard(
                                  key: ValueKey(group.key),
                                  group: group,
                                  queue: songs,
                                ),
                                _SongGenreGroup() => _StandaloneSongCard(
                                  key: ValueKey(group.key),
                                  song: group.song,
                                  queue: songs,
                                ),
                              };
                            },
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    right: 16,
                    bottom: (miniVisible ? miniBottom : systemBottom) + 26,
                    child: FloatingActionButton(
                      heroTag: 'genre-options-${widget.genreId}',
                      onPressed: songs.isEmpty
                          ? null
                          : () => _showGenreOptions(
                              songs,
                              isUnknownGenre: isUnknownGenre,
                            ),
                      backgroundColor: colors.tertiaryContainer,
                      foregroundColor: colors.onTertiaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.more_vert_rounded, size: 28),
                    ),
                  ),
                  if (miniVisible && !controller.fullPlayerVisible)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: systemBottom,
                      child: const MiniPlayer(
                        key: ValueKey('genre-mini-player'),
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
          );
        },
      ),
    );
  }

  Future<void> _showGenreOptions(
    List<Song> songs, {
    required bool isUnknownGenre,
  }) async {
    var quickFillRequested = false;
    final selected = await showModalBottomSheet<_GenreSort>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUnknownGenre) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () {
                        quickFillRequested = true;
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.secondaryContainer,
                        foregroundColor: colors.onSecondaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: const Text(
                        'Quick fill genres',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      AppScope.of(context).playShuffled(songs);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.secondaryContainer,
                      foregroundColor: colors.onSecondaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.shuffle_rounded),
                    label: const Text('Shuffle'),
                  ),
                ),
                const SizedBox(height: 12),
                RadioGroup<_GenreSort>(
                  groupValue: _sort,
                  onChanged: (value) {
                    if (value != null) Navigator.pop(context, value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final sort in _GenreSort.values)
                        RadioListTile<_GenreSort>(
                          value: sort,
                          secondary: Icon(switch (sort) {
                            _GenreSort.artist => Icons.person_rounded,
                            _GenreSort.album => Icons.album_rounded,
                            _GenreSort.title => Icons.title_rounded,
                          }),
                          title: Text(switch (sort) {
                            _GenreSort.artist => 'Sort by artist',
                            _GenreSort.album => 'Sort by album',
                            _GenreSort.title => 'Sort by title',
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _sort = selected);
    }
    if (quickFillRequested && mounted) {
      await _showQuickFill(songs);
    }
  }

  Future<void> _showQuickFill(List<Song> songs) async {
    final controller = AppScope.of(context);
    final customGenres = controller
        .stringListSetting('quick_fill_custom_genres', const [])
        .toSet();
    final iconCodes = <String, dynamic>{};
    try {
      iconCodes.addAll(
        Map<String, dynamic>.from(
          jsonDecode(controller.stringSetting('quick_fill_custom_icons', '{}'))
              as Map,
        ),
      );
    } on Object {
      // A malformed legacy preference should not block genre editing.
    }
    final customIcons = {
      for (final entry in iconCodes.entries)
        if (entry.value is num)
          entry.key: _quickFillIcon((entry.value as num).toInt()),
    };
    MetadataWriteResult? writeResult;
    final selectedGenre = await showDialog<String>(
      context: context,
      useSafeArea: false,
      builder: (context) => QuickFillDialog(
        songs: songs,
        customGenres: customGenres,
        customGenreIcons: customIcons,
        onAddCustomGenre: (entry) {
          customGenres.add(entry.$1);
          iconCodes[entry.$1] = entry.$2.codePoint;
          controller.setStringListSetting(
            'quick_fill_custom_genres',
            customGenres,
          );
          controller.setStringSetting(
            'quick_fill_custom_icons',
            jsonEncode(iconCodes),
          );
        },
        onApply: (selected, genre) async {
          writeResult = await controller.batchEditGenre(selected, genre);
          if (writeResult!.updatedSongIds.isNotEmpty) return null;
          return writeResult!.failures.values.firstOrNull ??
              'Could not update the selected files.';
        },
      ),
    );
    if (!mounted || selectedGenre == null) return;
    final result = writeResult;
    final failed = result?.failures.length ?? 0;
    final updated = result?.updatedSongIds.length ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? '$updated songs moved to $selectedGenre'
              : '$updated songs updated • $failed could not be written',
        ),
      ),
    );
  }
}

IconData _quickFillIcon(int codePoint) {
  const icons = [
    Icons.music_note_rounded,
    Icons.headphones_rounded,
    Icons.album_rounded,
    Icons.mic_external_on_rounded,
    Icons.speaker_rounded,
    Icons.favorite_rounded,
    Icons.piano_rounded,
    Icons.queue_music_rounded,
  ];
  return icons.firstWhere(
    (icon) => icon.codePoint == codePoint,
    orElse: () => Icons.music_note_rounded,
  );
}

class _GenreHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _GenreHeaderDelegate({
    required this.title,
    required this.minHeight,
    required this.startColor,
    required this.expandedContentColor,
    required this.onBack,
  });

  final String title;
  final double minHeight;
  final Color startColor;
  final Color expandedContentColor;
  final VoidCallback onBack;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => math.max(200, minHeight);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = Theme.of(context).colorScheme;
    final range = maxExtent - minExtent;
    final fraction = range == 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final solidAlpha = (fraction * 2).clamp(0.0, 1.0);
    final contentColor = Color.lerp(
      expandedContentColor,
      colors.onSurface,
      solidAlpha,
    )!;
    final statusBar = MediaQuery.paddingOf(context).top;
    final titleLeft = 20 + (68 - 20) * fraction;
    final titleSize = 36 + (20 - 36) * fraction;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.surfaceContainer.withValues(alpha: solidAlpha),
          colors.surface,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 1 - solidAlpha,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    startColor.withValues(alpha: .8),
                    startColor.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: statusBar + 4,
            child: SizedBox.square(
              dimension: 48,
              child: Material(
                color: contentColor.withValues(alpha: .1),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onBack,
                  customBorder: const CircleBorder(),
                  child: Icon(Icons.arrow_back_rounded, color: contentColor),
                ),
              ),
            ),
          ),
          Positioned(
            left: titleLeft,
            right: 20,
            bottom: 18 + (minExtent - statusBar - 58) * fraction,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: contentColor,
                fontFamily: 'GoogleSansFlex',
                fontSize: titleSize,
                height: 1.1,
                fontWeight: FontWeight.w500,
                letterSpacing: -.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _GenreHeaderDelegate oldDelegate) =>
      title != oldDelegate.title ||
      minHeight != oldDelegate.minHeight ||
      startColor != oldDelegate.startColor ||
      expandedContentColor != oldDelegate.expandedContentColor;
}

sealed class _GenreGroup {
  const _GenreGroup(this.key);

  final String key;
}

class _ArtistGenreGroup extends _GenreGroup {
  const _ArtistGenreGroup({required this.artist, required this.albums})
    : super('artist-$artist');

  final String artist;
  final List<_GenreAlbum> albums;
}

class _AlbumGenreGroup extends _GenreGroup {
  _AlbumGenreGroup(this.album) : super('album-${album.name}');

  final _GenreAlbum album;
}

class _SongGenreGroup extends _GenreGroup {
  _SongGenreGroup(this.song) : super('song-${song.id}');

  final Song song;
}

class _GenreAlbum {
  const _GenreAlbum({required this.name, required this.songs});

  final String name;
  final List<Song> songs;
}

List<_GenreGroup> _buildGroups(List<Song> source, _GenreSort sort) {
  if (sort == _GenreSort.title) {
    final songs = List<Song>.of(source)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return songs.map<_GenreGroup>(_SongGenreGroup.new).toList(growable: false);
  }

  if (sort == _GenreSort.album) {
    final albums = <String, List<Song>>{};
    final sorted = List<Song>.of(source)
      ..sort((a, b) => a.album.toLowerCase().compareTo(b.album.toLowerCase()));
    for (final song in sorted) {
      albums.putIfAbsent(song.album, () => <Song>[]).add(song);
    }
    return albums.entries
        .map<_GenreGroup>(
          (entry) => _AlbumGenreGroup(
            _GenreAlbum(name: entry.key, songs: _sortAlbumSongs(entry.value)),
          ),
        )
        .toList(growable: false);
  }

  final artists = <String, List<Song>>{};
  final sorted = List<Song>.of(source)
    ..sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
  for (final song in sorted) {
    artists.putIfAbsent(song.artist, () => <Song>[]).add(song);
  }
  return artists.entries
      .map<_GenreGroup>((artistEntry) {
        final albums = <String, List<Song>>{};
        for (final song in artistEntry.value) {
          albums.putIfAbsent(song.album, () => <Song>[]).add(song);
        }
        return _ArtistGenreGroup(
          artist: artistEntry.key,
          albums: albums.entries
              .map(
                (entry) => _GenreAlbum(
                  name: entry.key,
                  songs: _sortAlbumSongs(entry.value),
                ),
              )
              .toList(growable: false),
        );
      })
      .toList(growable: false);
}

List<Song> _sortAlbumSongs(List<Song> source) {
  return List<Song>.of(source)..sort((a, b) {
    final disc = a.disc.compareTo(b.disc);
    if (disc != 0) return disc;
    final track = a.track.compareTo(b.track);
    if (track != 0) return track;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
}

class _ArtistGroupCard extends StatelessWidget {
  const _ArtistGroupCard({required this.group, required this.queue, super.key});

  final _ArtistGenreGroup group;
  final List<Song> queue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sectionColor = Color.alphaBlend(
      colors.surfaceContainerLow.withValues(alpha: .5),
      colors.surface,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: sectionColor,
        child: Column(
          children: [
            _GenreArtistHeader(artist: group.artist),
            for (var index = 0; index < group.albums.length; index++) ...[
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Divider(
                    color: colors.outlineVariant.withValues(alpha: .3),
                  ),
                ),
              _GenreAlbumSection(album: group.albums[index], queue: queue),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlbumGroupCard extends StatelessWidget {
  const _AlbumGroupCard({required this.group, required this.queue, super.key});

  final _AlbumGenreGroup group;
  final List<Song> queue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: Color.alphaBlend(
          colors.surfaceContainerLow.withValues(alpha: .5),
          colors.surface,
        ),
        child: _GenreAlbumSection(album: group.album, queue: queue),
      ),
    );
  }
}

class _GenreArtistHeader extends StatelessWidget {
  const _GenreArtistHeader({required this.artist});

  final String artist;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 48,
              child: Material(
                color: colors.primaryContainer,
                shape: const CircleBorder(),
                child: Icon(
                  Icons.person_rounded,
                  size: 28,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                artist,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreAlbumSection extends StatelessWidget {
  const _GenreAlbumSection({required this.album, required this.queue});

  final _GenreAlbum album;
  final List<Song> queue;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final coverSong = album.songs.first;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Artwork(
                colors: coverSong.colors,
                mediaStoreId: coverSong.mediaStoreId,
                size: 48,
                borderRadius: 8,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${album.songs.length} ${album.songs.length == 1 ? 'Song' : 'Songs'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: 48,
                child: IconButton.filled(
                  onPressed: () => controller.playSong(
                    album.songs.first,
                    fromQueue: album.songs,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  tooltip: 'Play ${album.name}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            children: [
              for (var index = 0; index < album.songs.length; index++) ...[
                if (index > 0) const SizedBox(height: 2),
                _GenreSongItem(
                  key: ValueKey(album.songs[index].id),
                  song: album.songs[index],
                  queue: queue,
                  first: index == 0,
                  last: index == album.songs.length - 1,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StandaloneSongCard extends StatelessWidget {
  const _StandaloneSongCard({
    required this.song,
    required this.queue,
    super.key,
  });

  final Song song;
  final List<Song> queue;

  @override
  Widget build(BuildContext context) {
    return _GenreSongItem(song: song, queue: queue, first: true, last: true);
  }
}

class _GenreSongItem extends StatelessWidget {
  const _GenreSongItem({
    required this.song,
    required this.queue,
    required this.first,
    required this.last,
    super.key,
  });

  final Song song;
  final List<Song> queue;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final current = controller.currentSong?.id == song.id;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(first ? 16 : 4),
      topRight: Radius.circular(first ? 16 : 4),
      bottomLeft: Radius.circular(last ? 16 : 4),
      bottomRight: Radius.circular(last ? 16 : 4),
    );
    return Material(
      color: current ? colors.primaryContainer : colors.surfaceContainerLow,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => controller.playSong(song, fromQueue: queue),
        onLongPress: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: current
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            (current
                                    ? colors.onPrimaryContainer
                                    : colors.onSurface)
                                .withValues(alpha: .7),
                      ),
                    ),
                  ],
                ),
              ),
              if (current) ...[
                Icon(
                  controller.isPlaying
                      ? Icons.graphic_eq_rounded
                      : Icons.pause_rounded,
                  size: 18,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
              ],
              SizedBox.square(
                dimension: 36,
                child: IconButton.filled(
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: current
                        ? colors.onPrimaryContainer
                        : colors.surfaceContainerHigh,
                    foregroundColor: current
                        ? colors.primaryContainer
                        : colors.onSurface,
                  ),
                  onPressed: () => _showSongOptions(context),
                  icon: const Icon(Icons.more_vert_rounded, size: 24),
                  tooltip: 'More options for ${song.title}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSongOptions(BuildContext context) {
    final controller = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
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
              const ListTile(
                leading: Icon(Icons.playlist_play_rounded),
                title: Text('Play next'),
              ),
              const ListTile(
                leading: Icon(Icons.queue_music_rounded),
                title: Text('Add to queue'),
              ),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Song information'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreEmptyState extends StatelessWidget {
  const _GenreEmptyState({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_off_rounded,
              size: 54,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No $title songs',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _displayGenre(String raw) {
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}
