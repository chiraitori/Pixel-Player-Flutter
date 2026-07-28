import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../features/details/album_detail_screen.dart';
import '../../features/details/artist_detail_screen.dart';
import '../../features/player/song_info_bottom_sheet.dart';
import 'artwork.dart';
import 'playing_eq_icon.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    required this.song,
    this.queue,
    this.showTrackNumber = false,
    this.onMore,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectionIndex,
    super.key,
  });

  final Song song;
  final List<Song>? queue;
  final bool showTrackNumber;
  final VoidCallback? onMore;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final int? selectionIndex;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final current = controller.currentSong?.id == song.id;
    final colors = Theme.of(context).colorScheme;
    final selectionMode = onTap != null && onLongPress != null;
    final containerColor = selected
        ? colors.secondaryContainer
        : current
        ? colors.primaryContainer
        : colors.surfaceContainerLow;
    final contentColor = selected
        ? colors.onSecondaryContainer
        : current
        ? colors.onPrimaryContainer
        : colors.onSurface;
    final radius = current ? 50.0 : 22.0;

    return AnimatedScale(
      scale: selected ? .98 : 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
        decoration: ShapeDecoration(
          color: containerColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: selected
                ? BorderSide(color: colors.primary, width: 2.5)
                : BorderSide.none,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap ?? () => controller.playSong(song, fromQueue: queue),
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              child: Row(
                children: [
                  if (!showTrackNumber) ...[
                    Stack(
                      children: [
                        Artwork(
                          colors: song.colors,
                          size: 50,
                          borderRadius: current ? 50 : 10,
                          mediaStoreId: song.mediaStoreId,
                        ),
                        if (selected)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: .7),
                                borderRadius: BorderRadius.circular(
                                  current ? 50 : 10,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${selectionIndex ?? 1}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: colors.onPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                  ] else
                    const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: contentColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: contentColor.withValues(alpha: .7),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (current && !selectionMode) ...[
                    const SizedBox(width: 12),
                    controller.isPlaying
                        ? PlayingEqIcon(
                            isPlaying: true,
                            color: contentColor,
                          )
                        : Icon(
                            Icons.pause_rounded,
                            color: contentColor,
                            size: 18,
                          ),
                  ],
                  if (!selectionMode) ...[
                    const SizedBox(width: 12),
                    _MoreButton(
                      color: current
                          ? colors.primaryContainer
                          : colors.onSurface,
                      backgroundColor: current
                          ? colors.onPrimaryContainer
                          : colors.surfaceContainerHigh,
                      onTap: onMore ?? () => showMenu(context),
                      tooltip: 'More options for ${song.title}',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void showMenu(BuildContext context) {
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
                  size: 52,
                  borderRadius: 10,
                  mediaStoreId: song.mediaStoreId,
                ),
                title: Text(song.title),
                subtitle: Text('${song.artist} • ${song.album}'),
              ),
              const Divider(),
              _MenuItem(
                Icons.playlist_play_rounded,
                'Play next',
                onTap: () {
                  Navigator.pop(context);
                  controller.addSongNextToQueue(song);
                },
              ),
              _MenuItem(
                Icons.queue_music_rounded,
                'Add to queue',
                onTap: () {
                  Navigator.pop(context);
                  controller.addSongToQueue(song);
                },
              ),
              _MenuItem(
                Icons.playlist_add_rounded,
                'Add to playlist',
                onTap: () {
                  Navigator.pop(context);
                  _showPlaylistPicker(context);
                },
              ),
              _MenuItem(
                Icons.album_rounded,
                'Go to album',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AlbumDetailScreen(
                        albumId: song.albumId?.toString() ?? song.album,
                      ),
                    ),
                  );
                },
              ),
              _MenuItem(
                Icons.person_rounded,
                'Go to artist',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ArtistDetailScreen(
                        artistId: song.artistId?.toString() ?? song.artist,
                      ),
                    ),
                  );
                },
              ),
              _MenuItem(
                Icons.info_outline_rounded,
                'Song information',
                onTap: () {
                  Navigator.pop(context);
                  _showSongInformation(context);
                },
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
              const ListTile(
                leading: Icon(Icons.playlist_remove_rounded),
                title: Text('No playlists yet'),
              )
            else
              for (final playlist in controller.playlists)
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: Text(playlist.name),
                  subtitle: Text(
                    '${playlist.songs.length} '
                    '${playlist.songs.length == 1 ? 'Song' : 'Songs'}',
                  ),
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

  void _showSongInformation(BuildContext context) {
    showSongInfoBottomSheet(context: context, song: song);
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({
    required this.color,
    required this.backgroundColor,
    required this.onTap,
    required this.tooltip,
  });

  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          containedInkWell: false,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.more_vert_rounded, color: color, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem(this.icon, this.label, {required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onTap: onTap,
    );
  }
}
