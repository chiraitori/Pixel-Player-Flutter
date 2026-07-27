import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import 'playlist_cover.dart';

/// Flutter counterpart of Compose `PlaylistMultiSelectionBottomSheet`.
class PlaylistMultiSelectionSheet extends StatelessWidget {
  const PlaylistMultiSelectionSheet({
    required this.playlists,
    required this.onDelete,
    required this.onExport,
    required this.onMerge,
    required this.onShare,
    super.key,
  });

  final List<Playlist> playlists;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onMerge;
  final ValueChanged<BuildContext> onShare;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final songCount = playlists
        .expand((playlist) => playlist.songs)
        .map((song) => song.id)
        .toSet()
        .length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _StackedPlaylistCovers(playlists: playlists.take(4).toList()),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${playlists.length} PLAYLISTS',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$songCount songs selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    backgroundColor: colors.errorContainer,
                    foregroundColor: colors.onErrorContainer,
                    icon: Icons.delete_rounded,
                    label: 'Delete',
                    onPressed: onDelete,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    backgroundColor: colors.tertiaryContainer,
                    foregroundColor: colors.onTertiaryContainer,
                    icon: Icons.file_download_rounded,
                    label: 'Export',
                    onPressed: onExport,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    backgroundColor: colors.secondaryContainer,
                    foregroundColor: colors.onSecondaryContainer,
                    icon: Icons.merge_rounded,
                    label: 'Merge',
                    onPressed: onMerge,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Builder(
                    builder: (shareContext) => _ActionButton(
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                      icon: Icons.share_rounded,
                      label: 'Share',
                      onPressed: () => onShare(shareContext),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 66),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: const StadiumBorder(),
      ),
      icon: Icon(icon),
      label: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

class _StackedPlaylistCovers extends StatelessWidget {
  const _StackedPlaylistCovers({required this.playlists});

  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context) {
    const imageSize = 66.0;
    const overlap = 33.0;
    final width = playlists.isEmpty
        ? 0.0
        : imageSize + (playlists.length - 1) * (imageSize - overlap);
    final borderColor = Theme.of(context).colorScheme.surfaceContainerLow;
    return SizedBox(
      width: width,
      height: 74,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = playlists.length - 1; index >= 0; index--)
            Positioned(
              left: index * (imageSize - overlap),
              top: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: borderColor,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: PlaylistCover(
                      playlist: playlists[index],
                      size: imageSize - 6,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
