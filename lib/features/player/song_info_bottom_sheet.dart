import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/audio_meta_service.dart';
import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/artwork.dart';

/// Expressive two-page song sheet shared by queue rows and library song menus.
/// It follows Kotlin's SongInfoBottomSheet structure: persistent 80dp header,
/// actions/info pager, and the pill-shaped bottom tab selector.
Future<void> showSongInfoBottomSheet({
  required BuildContext context,
  required Song song,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _SongInfoBottomSheet(song: song),
  );
}

class _SongInfoBottomSheet extends StatefulWidget {
  const _SongInfoBottomSheet({required this.song});

  final Song song;

  @override
  State<_SongInfoBottomSheet> createState() => _SongInfoBottomSheetState();
}

class _SongInfoBottomSheetState extends State<_SongInfoBottomSheet> {
  late final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final screen = MediaQuery.sizeOf(context);
    final pagerHeight =
        (screen.height - MediaQuery.paddingOf(context).top - 250).clamp(
          280.0,
          480.0,
        );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                height: 80,
                child: Row(
                  children: [
                    Artwork(
                      colors: widget.song.colors,
                      size: 80,
                      borderRadius: 26,
                      mediaStoreId: widget.song.mediaStoreId,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.song.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w300),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Copy title',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.song.title),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Song title copied')),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: pagerHeight,
              child: PageView(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _page = value),
                children: [
                  _SongActionsPage(song: widget.song, controller: controller),
                  _SongDetailsPage(song: widget.song),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                height: 64,
                padding: const EdgeInsets.all(5),
                decoration: ShapeDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SongInfoTab(
                        selected: _page == 0,
                        icon: Icons.menu_rounded,
                        label: 'Options',
                        onTap: () => _selectPage(0),
                      ),
                    ),
                    Expanded(
                      child: _SongInfoTab(
                        selected: _page == 1,
                        icon: Icons.info_rounded,
                        label: 'Info',
                        onTap: () => _selectPage(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectPage(int page) {
    if (_page == page) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.fastOutSlowIn,
    );
  }
}

class _SongActionsPage extends StatelessWidget {
  const _SongActionsPage({required this.song, required this.controller});

  final Song song;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _ActionButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Play',
                    primary: true,
                    height: 80,
                    onTap: () {
                      controller.playSong(song, fromQueue: controller.queue);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: controller.isFavorite(song)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: 'Favorite',
                    iconOnly: true,
                    height: 80,
                    onTap: () => controller.toggleFavoriteFor(song),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    iconOnly: true,
                    height: 80,
                    onTap: () => unawaited(_shareSong(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.queue_music_rounded,
                    label: 'Add to queue',
                    onTap: () => controller.addSongToQueue(song),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.playlist_play_rounded,
                    label: 'Play next',
                    onTap: () => controller.addSongNextToQueue(song),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.playlist_add_rounded,
                    label: 'Playlist',
                    wide: true,
                    secondary: true,
                    height: 66,
                    onTap: () => _showPlaylistPicker(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.delete_forever_rounded,
                    label: 'Delete',
                    wide: true,
                    error: true,
                    height: 66,
                    onTap: () => unawaited(_deleteFromDevice(context)),
                  ),
                ),
              ],
            ),
            if (!Platform.isIOS) ...[
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.notifications_active_outlined,
                label: 'Set as sound',
                wide: true,
                onTap: () => unawaited(_setRingtone(context)),
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlaylistPicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SongPlaylistPicker(song: song, controller: controller),
    );
  }

  Future<void> _shareSong(BuildContext context) async {
    final shareText = '${song.title} — ${song.artist}';
    final localPath = song.path;
    final fileExists = localPath != null && await File(localPath).exists();
    await SharePlus.instance.share(
      ShareParams(
        text: shareText,
        title: song.title,
        subject: song.title,
        files: fileExists ? [XFile(localPath)] : null,
      ),
    );
  }

  Future<void> _deleteFromDevice(BuildContext context) async {
    if (song.source != SongSource.local || song.contentUri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only local MediaStore songs can be deleted.'),
        ),
      );
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded),
        title: const Text('Delete song?'),
        content: Text('Delete “${song.title}” from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !context.mounted) return;
    final response =
        await const MethodChannel(
          'com.chiraitori.pixelplay/device_capabilities',
        ).invokeMapMethod<String, dynamic>('deleteMediaStoreAudio', {
          'uri': song.contentUri,
        });
    if (!context.mounted) return;
    final status = response?['status'];
    if (status == 'success') {
      await controller.refreshLibrary();
      if (context.mounted) Navigator.pop(context);
      return;
    }
    if (status == 'cancelled') return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response?['message']?.toString() ??
              'The audio file could not be deleted.',
        ),
      ),
    );
  }

  Future<void> _setRingtone(BuildContext context) async {
    final localUri =
        song.contentUri ??
        (song.path == null ? null : Uri.file(song.path!).toString());
    if (localUri == null || song.source != SongSource.local) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only local songs can be used as a ringtone.'),
        ),
      );
      return;
    }
    final tone = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set as tone'),
        content: const Text('Choose where to use this local audio track.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'alarm'),
            child: const Text('Alarm'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'notification'),
            child: const Text('Notification'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'ringtone'),
            child: const Text('Ringtone'),
          ),
        ],
      ),
    );
    if (tone == null || !context.mounted) return;
    final response =
        await const MethodChannel(
          'com.chiraitori.pixelplay/device_capabilities',
        ).invokeMapMethod<String, dynamic>('setRingtone', {
          'uri': localUri,
          'tone': tone,
        });
    if (!context.mounted) return;
    final status = response?['status'];
    final message = switch (status) {
      'success' => '${song.title} set as $tone.',
      'permission' =>
        'Allow Modify system settings, then choose the tone again.',
      _ => response?['message']?.toString() ?? 'Could not set the tone.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SongPlaylistPicker extends StatefulWidget {
  const _SongPlaylistPicker({required this.song, required this.controller});

  final Song song;
  final AppController controller;

  @override
  State<_SongPlaylistPicker> createState() => _SongPlaylistPickerState();
}

class _SongPlaylistPickerState extends State<_SongPlaylistPicker> {
  final _search = TextEditingController();
  late final Set<String> _selected = {
    for (final playlist in widget.controller.playlists)
      if (playlist.songs.any((song) => song.id == widget.song.id)) playlist.id,
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final playlists = widget.controller.playlists
        .where(
          (playlist) =>
              query.isEmpty || playlist.name.toLowerCase().contains(query),
        )
        .toList(growable: false);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height * .72).clamp(360.0, 640.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select playlists',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Create playlist',
                    onPressed: _createPlaylist,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Search playlists',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                  filled: true,
                  fillColor: colors.surfaceContainerHigh,
                  border: const OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: playlists.isEmpty
                  ? const Center(child: Text('No playlists found'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      itemCount: playlists.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        final selected = _selected.contains(playlist.id);
                        return Material(
                          color: selected
                              ? colors.primaryContainer
                              : colors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                          child: CheckboxListTile(
                            value: selected,
                            onChanged: (value) => setState(() {
                              if (value == true) {
                                _selected.add(playlist.id);
                              } else {
                                _selected.remove(playlist.id);
                              }
                            }),
                            secondary: const Icon(Icons.queue_music_rounded),
                            title: Text(playlist.name),
                            subtitle: Text('${playlist.songs.length} songs'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save'),
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPlaylist() async {
    final name = TextEditingController();
    final created = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create playlist'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    name.dispose();
    if (!mounted || created == null || created.isEmpty) return;
    widget.controller.createPlaylist(created, [widget.song.id]);
    Navigator.pop(context);
  }

  void _save() {
    for (final playlist in widget.controller.playlists) {
      final containsSong = playlist.songs.any(
        (song) => song.id == widget.song.id,
      );
      final selected = _selected.contains(playlist.id);
      if (selected && !containsSong) {
        widget.controller.addSongsToPlaylist(playlist.id, [widget.song.id]);
      } else if (!selected && containsSong) {
        widget.controller.removeSongFromPlaylist(playlist.id, widget.song.id);
      }
    }
    Navigator.pop(context);
  }
}

class _SongDetailsPage extends StatelessWidget {
  const _SongDetailsPage({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final format = AudioMetaService.formatFor(
      filePath: song.path,
      contentUri: song.contentUri,
      mimeType: song.mimeType,
    );
    final formatParts = [
      if (song.sampleRate != null)
        '${(song.sampleRate! / 1000).toStringAsFixed(1)} kHz',
      if (song.bitrate != null) '${(song.bitrate! / 1000).round()} kbps',
      format.toUpperCase(),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _InfoSegment(
          icon: Icons.schedule_rounded,
          label: 'Duration',
          value: song.durationLabel,
        ),
        if (song.genre.isNotEmpty)
          _InfoSegment(
            icon: Icons.music_note_rounded,
            label: 'Genre',
            value: song.genre,
          ),
        _InfoSegment(
          icon: Icons.album_rounded,
          label: 'Album',
          value: song.album,
        ),
        _InfoSegment(
          icon: Icons.person_rounded,
          label: 'Artist',
          value: song.artist,
        ),
        _InfoSegment(
          icon: Icons.info_rounded,
          label: 'Audio format',
          value: formatParts.join(' • '),
        ),
        _InfoSegment(
          icon: song.source == SongSource.local
              ? Icons.audio_file_rounded
              : Icons.cloud_rounded,
          label: song.source == SongSource.local ? 'File' : 'Provider',
          value: song.path ?? song.contentUri ?? song.source.name,
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.wide = false,
    this.iconOnly = false,
    this.height = 74,
    this.secondary = false,
    this.error = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool wide;
  final bool iconOnly;
  final double height;
  final bool secondary;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = error
        ? colors.errorContainer
        : secondary
        ? colors.secondaryContainer
        : primary
        ? colors.primary
        : colors.surfaceContainerHigh;
    final foregroundColor = error
        ? colors.onErrorContainer
        : secondary
        ? colors.onSecondaryContainer
        : primary
        ? colors.onPrimary
        : colors.onSurface;
    return SizedBox(
      height: height,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(wide ? 24 : 26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor),
              if (iconOnly)
                const SizedBox.shrink()
              else if (wide) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: foregroundColor),
                ),
              ] else ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: foregroundColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSegment extends StatelessWidget {
  const _InfoSegment({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _SongInfoTab extends StatelessWidget {
  const _SongInfoTab({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.fastOutSlowIn,
      decoration: ShapeDecoration(
        color: selected ? colors.primary : Colors.transparent,
        shape: const StadiumBorder(),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? colors.onPrimary : colors.onSurface),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: selected ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
