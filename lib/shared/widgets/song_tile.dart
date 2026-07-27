import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../features/details/album_detail_screen.dart';
import '../../features/details/artist_detail_screen.dart';
import 'artwork.dart';

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

    return Material(
      color: selected
          ? colors.secondaryContainer
          : current
          ? colors.primaryContainer.withValues(alpha: .52)
          : Colors.transparent,
      borderRadius: current ? BorderRadius.circular(36) : BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => controller.playSong(song, fromQueue: queue),
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (selected)
                SizedBox(
                  width: showTrackNumber ? 34 : 52,
                  height: showTrackNumber ? 34 : 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${selectionIndex ?? 1}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                )
              else if (showTrackNumber)
                SizedBox(
                  width: 34,
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
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                )
              else
                Artwork(
                  colors: song.colors,
                  size: 52,
                  borderRadius: 10,
                  mediaStoreId: song.mediaStoreId,
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: controller.currentSong?.id == song.id
                            ? colors.primary
                            : null,
                        fontWeight: controller.currentSong?.id == song.id
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${song.artist} • ${song.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                song.durationLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              IconButton(
                onPressed: onMore ?? () => showMenu(context),
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'More options',
              ),
            ],
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
    final controller = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Artwork(
                colors: song.colors,
                size: 56,
                borderRadius: 12,
                mediaStoreId: song.mediaStoreId,
              ),
              title: Text(
                song.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(song.artist),
              trailing: IconButton(
                onPressed: () => controller.toggleFavoriteFor(song),
                icon: Icon(
                  controller.isFavorite(song)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
              ),
            ),
            const Divider(),
            _InfoLine('Album', song.album),
            _InfoLine('Artist', song.artist),
            _InfoLine('Genre', song.genre),
            _InfoLine('Year', '${song.year}'),
            _InfoLine('Track', '${song.track}'),
            _InfoLine('Duration', song.durationLabel),
            if (song.sampleRate != null)
              _InfoLine('Sample rate', '${song.sampleRate} Hz'),
            if (song.bitrate != null)
              _InfoLine('Bitrate', '${(song.bitrate! / 1000).round()} kbps'),
            if (song.mimeType != null) _InfoLine('Format', song.mimeType!),
            if (song.path != null) _InfoLine('Path', song.path!),
          ],
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

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
