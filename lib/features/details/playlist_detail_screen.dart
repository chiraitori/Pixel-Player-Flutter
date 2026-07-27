import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../player/full_player.dart';
import '../player/mini_player.dart';
import '../../shared/widgets/artwork.dart';

enum _PlaylistSort {
  manual,
  titleAscending,
  titleDescending,
  artistAscending,
  artistDescending,
  albumAscending,
  albumDescending,
  dateAddedNewest,
  dateAddedOldest,
  durationLongest,
  durationShortest,
}

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({required this.playlistId, super.key});

  final String playlistId;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  _PlaylistSort _sort = _PlaylistSort.manual;
  bool _removeMode = false;
  bool _reorderMode = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final matches = controller.playlists.where(
      (playlist) =>
          playlist.id == widget.playlistId ||
          playlist.name == widget.playlistId,
    );
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Playlist not found')),
      );
    }

    final playlist = matches.first;
    final songs = _sortedSongs(playlist.songs);
    final colors = Theme.of(context).colorScheme;
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
    final miniVisible = controller.currentSong != null;
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
            NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar.large(
                  pinned: true,
                  backgroundColor: colors.surface,
                  surfaceTintColor: Colors.transparent,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: IconButton.filledTonal(
                      key: const ValueKey('playlist-detail-back'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  titleSpacing: 8,
                  title: Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.fromLTRB(72, 0, 112, 18),
                    title: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${_songCount(songs.length)} • '
                          '${_totalDuration(songs)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: () => _showSortSheet(context),
                      icon: const Icon(Icons.sort_rounded),
                      tooltip: 'Sort songs',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: IconButton.filledTonal(
                        onPressed: () =>
                            _showPlaylistOptions(context, playlist),
                        icon: const Icon(Icons.more_vert_rounded),
                        tooltip: 'More options',
                      ),
                    ),
                  ],
                ),
              ],
              body: Column(
                children: [
                  _PlaybackActions(
                    enabled: songs.isNotEmpty,
                    onPlay: () {
                      if (songs.isNotEmpty) {
                        controller.playSong(songs.first, fromQueue: songs);
                      }
                    },
                    onShuffle: () => controller.playShuffled(songs),
                  ),
                  _EditActions(
                    removeMode: _removeMode,
                    reorderMode: _reorderMode,
                    onAdd: () => _showAddSongsSheet(context, playlist),
                    onToggleRemove: () => setState(() {
                      _removeMode = !_removeMode;
                      if (_removeMode) _reorderMode = false;
                    }),
                    onToggleReorder: () => setState(() {
                      _reorderMode = !_reorderMode;
                      if (_reorderMode) {
                        _removeMode = false;
                        _sort = _PlaylistSort.manual;
                      }
                    }),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      child: ColoredBox(
                        color: colors.surfaceContainerHigh,
                        child: songs.isEmpty
                            ? const _EmptyPlaylist()
                            : ReorderableListView.builder(
                                key: ValueKey(
                                  'playlist-songs-${playlist.id}-${_sort.name}',
                                ),
                                padding: EdgeInsets.fromLTRB(
                                  0,
                                  12,
                                  0,
                                  systemBottom +
                                      (miniVisible
                                          ? miniPlayerHeight +
                                                miniPlayerBottomSpacer
                                          : 0) +
                                      16,
                                ),
                                buildDefaultDragHandles: false,
                                itemCount: songs.length,
                                onReorderItem: _reorderMode
                                    ? (oldIndex, newIndex) {
                                        controller.reorderPlaylistSongs(
                                          playlist.id,
                                          oldIndex,
                                          newIndex,
                                        );
                                      }
                                    : (_, _) {},
                                proxyDecorator: (child, index, animation) =>
                                    AnimatedBuilder(
                                      animation: animation,
                                      builder: (context, _) => Transform.scale(
                                        scale: 1 + animation.value * .05,
                                        child: Material(
                                          color: Colors.transparent,
                                          elevation: animation.value * 6,
                                          child: child,
                                        ),
                                      ),
                                    ),
                                itemBuilder: (context, index) => Padding(
                                  key: ValueKey(songs[index].id),
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _PlaylistSongItem(
                                    song: songs[index],
                                    queue: songs,
                                    removeMode: _removeMode,
                                    reorderMode: _reorderMode,
                                    dragHandle: ReorderableDragStartListener(
                                      index: index,
                                      enabled: _reorderMode,
                                      child: const SizedBox.square(
                                        dimension: 48,
                                        child: Icon(
                                          Icons.drag_indicator_rounded,
                                        ),
                                      ),
                                    ),
                                    onRemove: () =>
                                        controller.removeSongFromPlaylist(
                                          playlist.id,
                                          songs[index].id,
                                        ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (miniVisible && !controller.fullPlayerVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: systemBottom,
                child: const MiniPlayer(
                  key: ValueKey('playlist-detail-mini-player'),
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
  }

  List<Song> _sortedSongs(List<Song> source) {
    final result = List<Song>.of(source);
    int text(String left, String right) =>
        left.toLowerCase().compareTo(right.toLowerCase());
    switch (_sort) {
      case _PlaylistSort.manual:
        return result;
      case _PlaylistSort.titleAscending:
        result.sort((a, b) => text(a.title, b.title));
      case _PlaylistSort.titleDescending:
        result.sort((a, b) => text(b.title, a.title));
      case _PlaylistSort.artistAscending:
        result.sort((a, b) => text(a.artist, b.artist));
      case _PlaylistSort.artistDescending:
        result.sort((a, b) => text(b.artist, a.artist));
      case _PlaylistSort.albumAscending:
        result.sort((a, b) => text(a.album, b.album));
      case _PlaylistSort.albumDescending:
        result.sort((a, b) => text(b.album, a.album));
      case _PlaylistSort.dateAddedNewest:
        result.sort(
          (a, b) => (b.dateAdded ?? DateTime(0)).compareTo(
            a.dateAdded ?? DateTime(0),
          ),
        );
      case _PlaylistSort.dateAddedOldest:
        result.sort(
          (a, b) => (a.dateAdded ?? DateTime(0)).compareTo(
            b.dateAdded ?? DateTime(0),
          ),
        );
      case _PlaylistSort.durationLongest:
        result.sort((a, b) => b.duration.compareTo(a.duration));
      case _PlaylistSort.durationShortest:
        result.sort((a, b) => a.duration.compareTo(b.duration));
    }
    return result;
  }

  Future<void> _showSortSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<_PlaylistSort>(
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
                'Sort songs',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final option in _PlaylistSort.values)
              ListTile(
                leading: Icon(
                  option == _sort
                      ? Icons.check_rounded
                      : Icons.sort_by_alpha_rounded,
                ),
                title: Text(_sortLabel(option)),
                selected: option == _sort,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _sort = selected);
  }

  Future<void> _showAddSongsSheet(
    BuildContext context,
    Playlist playlist,
  ) async {
    final controller = AppScope.of(context);
    final selected = <String>{for (final song in playlist.songs) song.id};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .82,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add songs',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, selected),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: controller.songs.length,
                    itemBuilder: (context, index) {
                      final song = controller.songs[index];
                      final checked = selected.contains(song.id);
                      return CheckboxListTile(
                        value: checked,
                        secondary: Artwork(
                          colors: song.colors,
                          mediaStoreId: song.mediaStoreId,
                          size: 48,
                          borderRadius: 10,
                        ),
                        title: Text(song.title),
                        subtitle: Text(song.artist),
                        onChanged: (_) => setSheetState(() {
                          checked
                              ? selected.remove(song.id)
                              : selected.add(song.id);
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    final additions = result.where(
      (id) => !playlist.songs.any((song) => song.id == id),
    );
    controller.addSongsToPlaylist(playlist.id, additions);
  }

  void _showPlaylistOptions(BuildContext context, Playlist playlist) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Playlist options',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(playlist.name),
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit playlist'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _renamePlaylist(context, playlist);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded),
                title: const Text('Delete playlist'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deletePlaylist(context, playlist);
                },
              ),
              ListTile(
                leading: const Icon(Icons.graphic_eq_rounded),
                title: const Text('Set default transition'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  AppScope.of(
                    context,
                  ).setStringSetting('transition_playlist_id', playlist.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Default transition set for playlist'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file_rounded),
                title: const Text('Export playlist'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _exportPlaylist(context, playlist);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renamePlaylist(BuildContext context, Playlist playlist) async {
    final text = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit playlist'),
        content: TextField(
          controller: text,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Playlist name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    text.dispose();
    if (name != null && context.mounted) {
      AppScope.of(context).renamePlaylist(playlist.id, name);
    }
  }

  Future<void> _deletePlaylist(BuildContext context, Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text(
          '“${playlist.name}” will be deleted. Your music files will not be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      AppScope.of(context).deletePlaylist(playlist.id);
      Navigator.pop(context);
    }
  }

  Future<void> _exportPlaylist(BuildContext context, Playlist playlist) async {
    final safeName = playlist.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export playlist',
      fileName: '$safeName.m3u',
      type: FileType.custom,
      allowedExtensions: const ['m3u'],
    );
    if (path == null) return;
    final contents = StringBuffer('#EXTM3U\n');
    for (final song in playlist.songs) {
      contents.writeln(
        '#EXTINF:${song.duration.inSeconds},${song.artist} - ${song.title}',
      );
      contents.writeln(song.path ?? song.contentUri ?? '');
    }
    await File(path).writeAsString(contents.toString());
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Exported ${playlist.name}')));
  }

  static String _sortLabel(_PlaylistSort option) => switch (option) {
    _PlaylistSort.manual => 'Default order',
    _PlaylistSort.titleAscending => 'Title A–Z',
    _PlaylistSort.titleDescending => 'Title Z–A',
    _PlaylistSort.artistAscending => 'Artist A–Z',
    _PlaylistSort.artistDescending => 'Artist Z–A',
    _PlaylistSort.albumAscending => 'Album A–Z',
    _PlaylistSort.albumDescending => 'Album Z–A',
    _PlaylistSort.dateAddedNewest => 'Date added — newest',
    _PlaylistSort.dateAddedOldest => 'Date added — oldest',
    _PlaylistSort.durationLongest => 'Duration — longest',
    _PlaylistSort.durationShortest => 'Duration — shortest',
  };

  static String _songCount(int count) =>
      '$count ${count == 1 ? 'Song' : 'Songs'}';

  static String _totalDuration(List<Song> songs) {
    final duration = songs.fold(
      Duration.zero,
      (total, song) => total + song.duration,
    );
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${duration.inMinutes} min';
  }
}

class _PlaybackActions extends StatelessWidget {
  const _PlaybackActions({
    required this.enabled,
    required this.onPlay,
    required this.onShuffle,
  });

  final bool enabled;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: Row(
          children: [
            Expanded(
              child: SizedBox.expand(
                child: FilledButton.icon(
                  onPressed: enabled ? onPlay : null,
                  style: FilledButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(60),
                        bottomLeft: Radius.circular(60),
                        topRight: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Play it'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox.expand(
                child: FilledButton.tonalIcon(
                  onPressed: enabled ? onShuffle : null,
                  style: FilledButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        topRight: Radius.circular(60),
                        bottomRight: Radius.circular(60),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Shuffle'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditActions extends StatelessWidget {
  const _EditActions({
    required this.removeMode,
    required this.reorderMode,
    required this.onAdd,
    required this.onToggleRemove,
    required this.onToggleReorder,
  });

  final bool removeMode;
  final bool reorderMode;
  final VoidCallback onAdd;
  final VoidCallback onToggleRemove;
  final VoidCallback onToggleReorder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
        children: [
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: colors.tertiaryContainer,
              foregroundColor: colors.onTertiaryContainer,
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onToggleRemove,
            style: FilledButton.styleFrom(
              backgroundColor: removeMode
                  ? colors.tertiary
                  : colors.surfaceContainerHigh,
              foregroundColor: removeMode
                  ? colors.onTertiary
                  : colors.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(removeMode ? 24 : 12),
              ),
            ),
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
            label: const Text('Remove'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onToggleReorder,
            style: FilledButton.styleFrom(
              backgroundColor: reorderMode
                  ? colors.tertiary
                  : colors.surfaceContainerHigh,
              foregroundColor: reorderMode
                  ? colors.onTertiary
                  : colors.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(reorderMode ? 24 : 12),
              ),
            ),
            icon: const Icon(Icons.drag_indicator_rounded, size: 20),
            label: const Text('Reorder'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistSongItem extends StatelessWidget {
  const _PlaylistSongItem({
    required this.song,
    required this.queue,
    required this.removeMode,
    required this.reorderMode,
    required this.dragHandle,
    required this.onRemove,
  });

  final Song song;
  final List<Song> queue;
  final bool removeMode;
  final bool reorderMode;
  final Widget dragHandle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final current = controller.currentSong?.id == song.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: current ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: reorderMode || removeMode
              ? null
              : () => controller.playSong(song, fromQueue: queue),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  Artwork(
                    colors: song.colors,
                    mediaStoreId: song.mediaStoreId,
                    size: 52,
                    borderRadius: 10,
                  ),
                  const SizedBox(width: 12),
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
                                color: current ? colors.primary : null,
                                fontWeight: current
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (removeMode)
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      tooltip: 'Remove ${song.title}',
                    )
                  else if (reorderMode)
                    dragHandle
                  else
                    IconButton(
                      onPressed: () => _showSongOptions(context),
                      icon: const Icon(Icons.more_vert_rounded),
                      tooltip: 'More options for ${song.title}',
                    ),
                ],
              ),
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
                title: Text(song.title),
                subtitle: Text('${song.artist} • ${song.album}'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded),
                title: const Text('Play next'),
                onTap: () {
                  Navigator.pop(context);
                  controller.addSongNextToQueue(song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: const Text('Add to queue'),
                onTap: () {
                  Navigator.pop(context);
                  controller.addSongToQueue(song);
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
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPlaylist extends StatelessWidget {
  const _EmptyPlaylist();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_off_rounded,
            size: 48,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'This playlist is empty',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Add some songs to get started',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
