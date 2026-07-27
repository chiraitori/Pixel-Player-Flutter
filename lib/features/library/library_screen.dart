import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/services/playlist_transfer_service.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/widgets/playlist_multi_selection_sheet.dart';
import '../../shared/widgets/song_tile.dart';
import 'widgets/library_empty_state.dart';
import 'widgets/tab_animation.dart';

enum LibrarySection {
  songs('Songs', Icons.music_note_rounded),
  albums('Albums', Icons.album_rounded),
  artists('Artists', Icons.person_rounded),
  playlists('Playlists', Icons.queue_music_rounded),
  genres('Genres', Icons.category_rounded),
  folders('Folders', Icons.folder_rounded),
  favorites('Favorites', Icons.favorite_rounded);

  const LibrarySection(this.label, this.icon);
  final String label;
  final IconData icon;
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.onOpenSettings,
    required this.onOpenAlbum,
    required this.onOpenArtist,
    required this.onOpenPlaylist,
    required this.onOpenGenre,
    required this.onCreatePlaylist,
    super.key,
  });

  final VoidCallback onOpenSettings;
  final ValueChanged<String> onOpenAlbum;
  final ValueChanged<String> onOpenArtist;
  final ValueChanged<String> onOpenPlaylist;
  final ValueChanged<String> onOpenGenre;
  final VoidCallback onCreatePlaylist;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final PageController _pages;
  late final ScrollController _songsScroll;
  late final ScrollController _favoritesScroll;
  LibrarySection _section = LibrarySection.songs;
  bool _grid = true;
  String _sort = 'Title';
  int _storageFilter = 0;
  final List<Song> _selectedSongs = [];
  final Set<String> _selectedMediaIds = {};

  @override
  void initState() {
    super.initState();
    _pages = PageController();
    _songsScroll = ScrollController()..addListener(_onSongListScrolled);
    _favoritesScroll = ScrollController();
  }

  @override
  void dispose() {
    _pages.dispose();
    _songsScroll
      ..removeListener(_onSongListScrolled)
      ..dispose();
    _favoritesScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final songs = _sortedSongs(
      controller.songs.where(_matchesStorageFilter).toList(),
    );
    final visibleSongIds = songs.map((song) => song.id).toSet();
    final albums = controller.albums
        .where(
          (album) =>
              album.songs.any((song) => visibleSongIds.contains(song.id)),
        )
        .toList();
    final artists = controller.artists
        .where(
          (artist) =>
              artist.songs.any((song) => visibleSongIds.contains(song.id)),
        )
        .toList();
    final playlists = [...controller.playlists];
    switch (_sort) {
      case 'Artist':
        albums.sort(
          (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
        );
        artists.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case 'Date added':
        albums.sort(
          (a, b) => (b.songs.first.dateAdded ?? DateTime(0)).compareTo(
            a.songs.first.dateAdded ?? DateTime(0),
          ),
        );
        break;
      default:
        albums.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        artists.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        playlists.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
    }
    final favoriteSongs = _sortedSongs(
      controller.favoriteSongs.where(_matchesStorageFilter).toList(),
    );
    final compact = controller.libraryCompactMode;
    final locateVisible = _currentSongOutsideViewport(controller, songs);
    final selectionCount =
        _section == LibrarySection.songs || _section == LibrarySection.favorites
        ? _selectedSongs.length
        : _selectedMediaIds.length;
    final selectedActionSongs = _selectedSongsForCurrentSection(
      songs: songs,
      albums: albums,
      artists: artists,
      playlists: playlists,
    );
    final selectedPlaylists = playlists
        .where((playlist) => _selectedMediaIds.contains(playlist.id))
        .toList(growable: false);
    return PopScope(
      canPop: selectionCount == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectionCount > 0) {
          setState(_clearSelection);
        }
      },
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _LibraryHeader(
              section: _section,
              compact: compact,
              onOpenSettings: widget.onOpenSettings,
              onOpenSections: () => _showSectionPicker(context),
              onSelectSection: (section) {
                _pages.animateToPage(
                  LibrarySection.values.indexOf(section),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: .4),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(34),
                ),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    children: [
                      if (selectionCount > 0)
                        _LibrarySelectionRow(
                          selectedCount: selectionCount,
                          onSelectAll: () => setState(
                            () => _selectAllCurrentSection(
                              songs: songs,
                              favoriteSongs: favoriteSongs,
                              albums: albums,
                              artists: artists,
                              playlists: playlists,
                            ),
                          ),
                          onOptions: () => _section == LibrarySection.playlists
                              ? _showSelectedPlaylistOptions(selectedPlaylists)
                              : _showSelectedSongOptions(selectedActionSongs),
                          onClear: () => setState(_clearSelection),
                        )
                      else
                        _LibraryActionRow(
                          isPlaylist: _section == LibrarySection.playlists,
                          showLocate: locateVisible,
                          showStorageFilter: switch (_section) {
                            LibrarySection.songs ||
                            LibrarySection.albums ||
                            LibrarySection.artists ||
                            LibrarySection.favorites => true,
                            _ => false,
                          },
                          storageFilter: _storageFilter,
                          onMainAction: () =>
                              _runMainAction(controller, songs, favoriteSongs),
                          onLocate: () => _locateCurrentSong(controller, songs),
                          onStorageFilter: () {
                            setState(() {
                              _storageFilter = (_storageFilter + 1) % 3;
                            });
                          },
                          onSort: () => _showSortSheet(context),
                        ),
                      Expanded(
                        child: PageView(
                          controller: _pages,
                          onPageChanged: (index) {
                            setState(() {
                              _section = LibrarySection.values[index];
                              _clearSelection();
                            });
                          },
                          children: [
                            _SongsTab(
                              songs: songs,
                              controller: _songsScroll,
                              selectedSongs: _selectedSongs,
                              onToggleSelection: _toggleSongSelection,
                            ),
                            _AlbumsTab(
                              albums: albums,
                              grid: _grid,
                              selectedIds: _selectedMediaIds,
                              onOpen: widget.onOpenAlbum,
                              onToggleSelection: _toggleMediaSelection,
                              onToggleLayout: () =>
                                  setState(() => _grid = !_grid),
                            ),
                            _ArtistsTab(
                              artists: artists,
                              selectedIds: _selectedMediaIds,
                              onOpen: widget.onOpenArtist,
                              onToggleSelection: _toggleMediaSelection,
                            ),
                            _PlaylistsTab(
                              playlists: playlists,
                              selectedIds: _selectedMediaIds,
                              onOpen: widget.onOpenPlaylist,
                              onToggleSelection: _toggleMediaSelection,
                              onCreate: widget.onCreatePlaylist,
                            ),
                            _GenresTab(
                              songs: songs,
                              selectedIds: _selectedMediaIds,
                              onOpen: widget.onOpenGenre,
                              onToggleSelection: _toggleMediaSelection,
                            ),
                            _FoldersTab(songs: songs),
                            _SongsTab(
                              songs: favoriteSongs,
                              controller: _favoritesScroll,
                              selectedSongs: _selectedSongs,
                              onToggleSelection: _toggleSongSelection,
                              emptyIcon: Icons.favorite_rounded,
                              emptyTitle: 'No liked songs yet',
                              emptySubtitle:
                                  'Tap the heart icon while playing a song to save it here.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSongListScrolled() {
    if (mounted) setState(() {});
  }

  bool _matchesStorageFilter(Song song) {
    if (_storageFilter == 0) return true;
    final uri = song.contentUri?.toLowerCase() ?? '';
    final isOnline =
        uri.startsWith('http://') ||
        uri.startsWith('https://') ||
        uri.startsWith('telegram://') ||
        uri.startsWith('gdrive://') ||
        uri.startsWith('jellyfin://') ||
        uri.startsWith('netease://') ||
        uri.startsWith('qqmusic://');
    return _storageFilter == 1 ? isOnline : !isOnline;
  }

  bool _currentSongOutsideViewport(AppController controller, List<Song> songs) {
    if (_section != LibrarySection.songs || controller.currentSong == null) {
      return false;
    }
    final index = songs.indexWhere(
      (song) => song.id == controller.currentSong!.id,
    );
    if (index < 0 || !_songsScroll.hasClients) return index < 0;
    const itemExtent = 82.0;
    final first = (_songsScroll.offset / itemExtent).floor();
    final last =
        ((_songsScroll.offset + _songsScroll.position.viewportDimension) /
                itemExtent)
            .floor();
    return index < first || index > last;
  }

  void _locateCurrentSong(AppController controller, List<Song> songs) {
    final current = controller.currentSong;
    if (current == null || !_songsScroll.hasClients) return;
    final index = songs.indexWhere((song) => song.id == current.id);
    if (index < 0) return;
    _songsScroll.animateTo(
      (index * 82.0).clamp(0, _songsScroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _runMainAction(
    AppController controller,
    List<Song> songs,
    List<Song> favoriteSongs,
  ) {
    if (_section == LibrarySection.playlists) {
      widget.onCreatePlaylist();
      return;
    }
    final queue = _section == LibrarySection.favorites ? favoriteSongs : songs;
    if (queue.isNotEmpty) controller.playShuffled(queue);
  }

  void _toggleSongSelection(Song song) {
    setState(() {
      final index = _selectedSongs.indexWhere((item) => item.id == song.id);
      index < 0 ? _selectedSongs.add(song) : _selectedSongs.removeAt(index);
    });
  }

  void _toggleMediaSelection(String id) {
    setState(() {
      _selectedMediaIds.contains(id)
          ? _selectedMediaIds.remove(id)
          : _selectedMediaIds.add(id);
    });
  }

  void _clearSelection() {
    _selectedSongs.clear();
    _selectedMediaIds.clear();
  }

  void _selectAllCurrentSection({
    required List<Song> songs,
    required List<Song> favoriteSongs,
    required List<Album> albums,
    required List<Artist> artists,
    required List<Playlist> playlists,
  }) {
    switch (_section) {
      case LibrarySection.songs:
        _selectedSongs
          ..clear()
          ..addAll(songs);
      case LibrarySection.favorites:
        _selectedSongs
          ..clear()
          ..addAll(favoriteSongs);
      case LibrarySection.albums:
        _selectedMediaIds
          ..clear()
          ..addAll(albums.map((album) => album.id));
      case LibrarySection.artists:
        _selectedMediaIds
          ..clear()
          ..addAll(artists.map((artist) => artist.id));
      case LibrarySection.playlists:
        _selectedMediaIds
          ..clear()
          ..addAll(playlists.map((playlist) => playlist.id));
      case LibrarySection.genres:
        _selectedMediaIds
          ..clear()
          ..addAll(songs.map((song) => song.genre));
      case LibrarySection.folders:
        break;
    }
  }

  List<Song> _selectedSongsForCurrentSection({
    required List<Song> songs,
    required List<Album> albums,
    required List<Artist> artists,
    required List<Playlist> playlists,
  }) {
    final selected = switch (_section) {
      LibrarySection.songs || LibrarySection.favorites => _selectedSongs,
      LibrarySection.albums =>
        albums
            .where((album) => _selectedMediaIds.contains(album.id))
            .expand((album) => album.songs),
      LibrarySection.artists =>
        artists
            .where((artist) => _selectedMediaIds.contains(artist.id))
            .expand((artist) => artist.songs),
      LibrarySection.playlists =>
        playlists
            .where((playlist) => _selectedMediaIds.contains(playlist.id))
            .expand((playlist) => playlist.songs),
      LibrarySection.genres => songs.where(
        (song) => _selectedMediaIds.contains(song.genre),
      ),
      LibrarySection.folders => const <Song>[],
    };
    final byId = <String, Song>{};
    for (final song in selected) {
      byId.putIfAbsent(song.id, () => song);
    }
    return byId.values.toList(growable: false);
  }

  void _showSelectedSongOptions(List<Song> selected) {
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The selected items contain no songs.')),
      );
      return;
    }
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
                title: Text(
                  '${selected.length} selected',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('Play selected'),
                onTap: () {
                  Navigator.pop(context);
                  controller.playSong(selected.first, fromQueue: selected);
                  setState(_clearSelection);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded),
                title: const Text('Play next'),
                onTap: () {
                  Navigator.pop(context);
                  for (final song in selected.reversed) {
                    controller.addSongNextToQueue(song);
                  }
                  setState(_clearSelection);
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: const Text('Add to queue'),
                onTap: () {
                  Navigator.pop(context);
                  for (final song in selected) {
                    controller.addSongToQueue(song);
                  }
                  setState(_clearSelection);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Add to playlist'),
                onTap: () {
                  Navigator.pop(context);
                  _showSelectedPlaylistPicker(selected);
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite_rounded),
                title: const Text('Like all'),
                onTap: () {
                  Navigator.pop(context);
                  controller.setFavoriteSongs(selected, true);
                  setState(_clearSelection);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectedPlaylistOptions(List<Playlist> selected) {
    if (selected.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => PlaylistMultiSelectionSheet(
        playlists: selected,
        onDelete: () {
          Navigator.pop(sheetContext);
          _confirmDeletePlaylists(selected);
        },
        onExport: () {
          Navigator.pop(sheetContext);
          _exportSelectedPlaylists(selected);
        },
        onMerge: () {
          Navigator.pop(sheetContext);
          _mergeSelectedPlaylists(selected);
        },
        onShare: (originContext) {
          Navigator.pop(sheetContext);
          _shareSelectedPlaylists(selected, originContext);
        },
      ),
    );
  }

  Future<void> _exportSelectedPlaylists(List<Playlist> selected) async {
    try {
      final count = await PlaylistTransferService.exportPlaylists(selected);
      if (count == null || !mounted) return;
      setState(_clearSelection);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exported $count playlists')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export playlists: $error')),
      );
    }
  }

  Future<void> _shareSelectedPlaylists(
    List<Playlist> selected,
    BuildContext originContext,
  ) async {
    final renderBox = originContext.findRenderObject() as RenderBox?;
    final origin = renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;
    try {
      await PlaylistTransferService.sharePlaylists(
        selected,
        sharePositionOrigin: origin,
      );
      if (!mounted) return;
      setState(_clearSelection);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share playlists: $error')),
      );
    }
  }

  Future<void> _confirmDeletePlaylists(List<Playlist> selected) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded),
        title: const Text('Delete playlists?'),
        content: Text(
          'Delete ${selected.length} selected playlists? Your audio files will not be removed.',
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
    if (confirmed != true || !mounted) return;
    final controller = AppScope.of(context);
    for (final playlist in selected) {
      controller.deletePlaylist(playlist.id);
    }
    setState(_clearSelection);
  }

  Future<void> _mergeSelectedPlaylists(List<Playlist> selected) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.merge_rounded),
          title: const Text('Merge playlists'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            onChanged: (_) => setDialogState(() {}),
            decoration: const InputDecoration(labelText: 'New playlist name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: nameController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, nameController.text.trim()),
              child: const Text('Merge'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    if (name == null || !mounted) return;
    final songIds = selected
        .expand((playlist) => playlist.songs)
        .map((song) => song.id)
        .toSet();
    AppScope.of(context).createPlaylist(name, songIds);
    setState(_clearSelection);
  }

  void _showSelectedPlaylistPicker(List<Song> selected) {
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
                  onTap: () {
                    controller.addSongsToPlaylist(
                      playlist.id,
                      selected.map((song) => song.id),
                    );
                    Navigator.pop(context);
                    setState(_clearSelection);
                  },
                ),
          ],
        ),
      ),
    );
  }

  void _showSectionPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Library tabs',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a section or reorder tabs.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.05,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: LibrarySection.values.length,
                itemBuilder: (context, index) {
                  final section = LibrarySection.values[index];
                  final selected = section == _section;
                  return Material(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        Navigator.pop(context);
                        _pages.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(section.icon),
                          const SizedBox(height: 8),
                          Text(section.label),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Sort ${_section.label.toLowerCase()}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              RadioGroup<String>(
                groupValue: _sort,
                onChanged: (value) {
                  if (value != null) setState(() => _sort = value);
                  Navigator.pop(context);
                },
                child: Column(
                  children: [
                    for (final option in [
                      'Title',
                      'Artist',
                      'Album',
                      'Date added',
                    ])
                      RadioListTile<String>(value: option, title: Text(option)),
                  ],
                ),
              ),
              SwitchListTile(
                value: _grid,
                onChanged: (value) {
                  setState(() => _grid = value);
                  Navigator.pop(context);
                },
                title: const Text('Grid view'),
                secondary: const Icon(Icons.grid_view_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Song> _sortedSongs(List<Song> source) {
    final sorted = [...source];
    switch (_sort) {
      case 'Artist':
        sorted.sort(
          (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
        );
        break;
      case 'Album':
        sorted.sort(
          (a, b) => a.album.toLowerCase().compareTo(b.album.toLowerCase()),
        );
        break;
      case 'Date added':
        sorted.sort(
          (a, b) => (b.dateAdded ?? DateTime(0)).compareTo(
            a.dateAdded ?? DateTime(0),
          ),
        );
        break;
      default:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
    }
    return sorted;
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.section,
    required this.compact,
    required this.onOpenSettings,
    required this.onOpenSections,
    required this.onSelectSection,
  });

  final LibrarySection section;
  final bool compact;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenSections;
  final ValueChanged<LibrarySection> onSelectSection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.primaryContainer.withValues(alpha: .4),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 22, 6),
            child: Row(
              children: [
                if (compact)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _CompactLibraryPill(
                        section: section,
                        onTap: onOpenSections,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'Library',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 40,
                              letterSpacing: 1,
                            ),
                      ),
                    ),
                  ),
                _LibrarySettingsButton(onPressed: onOpenSettings),
              ],
            ),
          ),
          if (compact)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final item in LibrarySection.values)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: item == section ? 22 : 10,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: item == section
                            ? colors.primary
                            : colors.primary.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
            )
          else
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final item in LibrarySection.values)
                    _LibraryTabButton(
                      section: item,
                      index: LibrarySection.values.indexOf(item),
                      selectedIndex: LibrarySection.values.indexOf(section),
                      onTap: () => onSelectSection(item),
                    ),
                  IconButton(
                    onPressed: onOpenSections,
                    icon: const Icon(Icons.edit_rounded),
                    tooltip: 'Reorder tabs',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactLibraryPill extends StatelessWidget {
  const _CompactLibraryPill({required this.section, required this.onTap});

  final LibrarySection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const outerRadius = Radius.circular(26);
    const innerRadius = Radius.circular(4);
    return SizedBox(
      height: 52,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SizedBox(
              key: const ValueKey('library-section-segment'),
              height: 52,
              child: Material(
                color: colors.primaryContainer,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: outerRadius,
                    bottomLeft: outerRadius,
                    topRight: innerRadius,
                    bottomRight: innerRadius,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          section.icon,
                          size: 22,
                          color: colors.onPrimaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(.18, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: Text(
                              section.label,
                              key: ValueKey(section),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onPrimaryContainer,
                                fontFamily: 'GoogleSansFlex',
                                fontWeight: FontWeight.w600,
                                fontSize: 26,
                                height: 28 / 26,
                                letterSpacing: -.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: colors.primaryContainer,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: innerRadius,
                bottomLeft: innerRadius,
                topRight: outerRadius,
                bottomRight: outerRadius,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                key: const ValueKey('library-section-arrow-segment'),
                width: 56,
                height: 52,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySettingsButton extends StatelessWidget {
  const _LibrarySettingsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 48,
      child: Center(
        child: SizedBox.square(
          dimension: 40,
          child: Material(
            color: colors.primaryContainer,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Tooltip(
                message: 'Settings',
                child: Icon(
                  Icons.settings_rounded,
                  color: colors.onPrimaryContainer,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryTabButton extends StatelessWidget {
  const _LibraryTabButton({
    required this.section,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  final LibrarySection section;
  final int index;
  final int selectedIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    return TabAnimation(
      index: index,
      selectedIndex: selectedIndex,
      title: section.label,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          section.label.toUpperCase(),
          style: TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SongsTab extends StatelessWidget {
  const _SongsTab({
    required this.songs,
    required this.controller,
    required this.selectedSongs,
    required this.onToggleSelection,
    this.emptyIcon = Icons.music_off_rounded,
    this.emptyTitle = 'No songs yet',
    this.emptySubtitle =
        'Add music to your device or sync a cloud source to start listening.',
  });

  final List<Song> songs;
  final ScrollController controller;
  final List<Song> selectedSongs;
  final ValueChanged<Song> onToggleSelection;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return LibraryEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }
    return ListView.separated(
      key: const PageStorageKey('library-songs'),
      controller: controller,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 224),
      itemCount: songs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final song = songs[index];
        final selectionIndex = selectedSongs.indexWhere(
          (item) => item.id == song.id,
        );
        return _LibrarySongItem(
          key: ValueKey('library-song-${song.id}'),
          song: song,
          queue: songs,
          selected: selectionIndex >= 0,
          selectionIndex: selectionIndex + 1,
          selectionMode: selectedSongs.isNotEmpty,
          onToggleSelection: () => onToggleSelection(song),
        );
      },
    );
  }
}

class _AlbumsTab extends StatelessWidget {
  const _AlbumsTab({
    required this.albums,
    required this.grid,
    required this.selectedIds,
    required this.onOpen,
    required this.onToggleSelection,
    required this.onToggleLayout,
  });

  final List<Album> albums;
  final bool grid;
  final Set<String> selectedIds;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onToggleSelection;
  final VoidCallback onToggleLayout;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.album_rounded,
        title: 'No albums available',
        subtitle:
            'Albums will appear here as soon as your library has grouped tracks.',
      );
    }
    if (!grid) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 224),
        itemCount: albums.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _LayoutToggle(
              grid: grid,
              albumCount: albums.length,
              onTap: onToggleLayout,
            );
          }
          final album = albums[index - 1];
          final selected = selectedIds.contains(album.id);
          return ListTile(
            selected: selected,
            selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 6,
            ),
            leading: Artwork(
              colors: album.colors,
              size: 64,
              borderRadius: 12,
              mediaStoreId: album.songs.first.mediaStoreId,
            ),
            title: Text(album.title),
            subtitle: Text('${album.artist} • ${album.songs.length} songs'),
            trailing: selected
                ? const _MediaSelectionBadge()
                : const Icon(Icons.more_vert_rounded),
            onTap: () => selectedIds.isNotEmpty
                ? onToggleSelection(album.id)
                : onOpen(album.id),
            onLongPress: () => onToggleSelection(album.id),
          );
        },
      );
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _LayoutToggle(
            grid: grid,
            albumCount: albums.length,
            onTap: onToggleLayout,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 224),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: .78,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              final selected = selectedIds.contains(album.id);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(selected ? 4 : 0),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(selected ? 28 : 20),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(selected ? 24 : 20),
                  onTap: () => selectedIds.isNotEmpty
                      ? onToggleSelection(album.id)
                      : onOpen(album.id),
                  onLongPress: () => onToggleSelection(album.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Artwork(
                              colors: album.colors,
                              borderRadius: selected ? 24 : 20,
                              mediaStoreId: album.songs.first.mediaStoreId,
                            ),
                            if (selected)
                              const Positioned(
                                top: 8,
                                right: 8,
                                child: _MediaSelectionBadge(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        album.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArtistsTab extends StatelessWidget {
  const _ArtistsTab({
    required this.artists,
    required this.selectedIds,
    required this.onOpen,
    required this.onToggleSelection,
  });

  final List<Artist> artists;
  final Set<String> selectedIds;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onToggleSelection;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.person_rounded,
        title: 'No artists available',
        subtitle: 'Artists are shown after songs are indexed from any source.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 224),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final selected = selectedIds.contains(artist.id);
        return ListTile(
          selected: selected,
          selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: ClipOval(
            child: Artwork(
              colors: artist.colors,
              size: 68,
              borderRadius: 0,
              mediaStoreId: artist.songs.first.mediaStoreId,
            ),
          ),
          title: Text(
            artist.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text('${artist.songs.length} songs'),
          trailing: selected ? const _MediaSelectionBadge() : null,
          onTap: () => selectedIds.isNotEmpty
              ? onToggleSelection(artist.id)
              : onOpen(artist.id),
          onLongPress: () => onToggleSelection(artist.id),
        );
      },
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab({
    required this.playlists,
    required this.selectedIds,
    required this.onOpen,
    required this.onToggleSelection,
    required this.onCreate,
  });

  final List<Playlist> playlists;
  final Set<String> selectedIds;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onToggleSelection;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create playlist'),
              ),
            ),
          ),
          const Expanded(
            child: LibraryEmptyState(
              icon: Icons.playlist_play_rounded,
              title: 'No playlists yet',
              subtitle: 'Create your first playlist to organize your library.',
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 224),
      itemCount: playlists.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.tonalIcon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create playlist'),
            ),
          );
        }
        final playlist = playlists[index - 1];
        final selected = selectedIds.contains(playlist.id);
        return Card(
          color: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: SizedBox(
              width: 64,
              height: 64,
              child: PlaylistCover(playlist: playlist, size: 64),
            ),
            title: Text(
              playlist.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('${playlist.songs.length} songs'),
            trailing: selected
                ? const _MediaSelectionBadge()
                : const Icon(Icons.arrow_forward_rounded),
            onTap: () => selectedIds.isNotEmpty
                ? onToggleSelection(playlist.id)
                : onOpen(playlist.id),
            onLongPress: () => onToggleSelection(playlist.id),
          ),
        );
      },
    );
  }
}

class _GenresTab extends StatelessWidget {
  const _GenresTab({
    required this.songs,
    required this.selectedIds,
    required this.onOpen,
    required this.onToggleSelection,
  });

  final List<Song> songs;
  final Set<String> selectedIds;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final genres = songs.map((song) => song.genre).toSet().toList();
    if (genres.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.category_rounded,
        title: 'No genres available',
        subtitle: 'Genres appear after songs with genre metadata are indexed.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 224),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.32,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: genres.length,
      itemBuilder: (context, index) {
        final genre = genres[index];
        final song = songs.firstWhere((item) => item.genre == genre);
        final selected = selectedIds.contains(genre);
        return Material(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : song.colors.first,
          borderRadius: BorderRadius.circular(selected ? 34 : 26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => selectedIds.isNotEmpty
                ? onToggleSelection(genre)
                : onOpen(genre),
            onLongPress: () => onToggleSelection(genre),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -24,
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 100,
                    color: Colors.white.withValues(alpha: .16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    genre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected)
                  const Positioned(
                    right: 12,
                    top: 12,
                    child: _MediaSelectionBadge(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FoldersTab extends StatelessWidget {
  const _FoldersTab({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Song>>{};
    for (final song in songs) {
      final path = song.path;
      if (path == null || !path.contains('/')) continue;
      final separator = path.lastIndexOf('/');
      final directory = path.substring(0, separator);
      final name = directory.substring(directory.lastIndexOf('/') + 1);
      grouped.putIfAbsent(name, () => []).add(song);
    }
    final folders = grouped.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    if (folders.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.folder_rounded,
        title: 'No folders found',
        subtitle: 'Internal storage folders with music will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 224),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.folder_rounded, size: 36),
            title: Text(folder.key),
            subtitle: Text('${folder.value.length} songs'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => DraggableScrollableSheet(
                expand: false,
                initialChildSize: .72,
                maxChildSize: .94,
                builder: (context, scrollController) => Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.folder_rounded),
                      title: Text(folder.key),
                      subtitle: Text('${folder.value.length} songs'),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: folder.value.length,
                        itemBuilder: (context, index) => SongTile(
                          song: folder.value[index],
                          queue: folder.value,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LibrarySelectionRow extends StatelessWidget {
  const _LibrarySelectionRow({
    required this.selectedCount,
    required this.onSelectAll,
    required this.onOptions,
    required this.onClear,
  });

  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onOptions;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$selectedCount selected',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onSelectAll,
              icon: const Icon(Icons.select_all_rounded),
              tooltip: 'Select all',
            ),
            IconButton.filledTonal(
              onPressed: onOptions,
              icon: const Icon(Icons.more_horiz_rounded),
              tooltip: 'Selection options',
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Clear selection',
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaSelectionBadge extends StatelessWidget {
  const _MediaSelectionBadge();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: colors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: colors.surface, width: 2),
      ),
      child: Icon(Icons.check_rounded, size: 18, color: colors.onPrimary),
    );
  }
}

class _LibraryActionRow extends StatelessWidget {
  const _LibraryActionRow({
    required this.isPlaylist,
    required this.showLocate,
    required this.showStorageFilter,
    required this.storageFilter,
    required this.onMainAction,
    required this.onLocate,
    required this.onStorageFilter,
    required this.onSort,
  });

  final bool isPlaylist;
  final bool showLocate;
  final bool showStorageFilter;
  final int storageFilter;
  final VoidCallback onMainAction;
  final VoidCallback onLocate;
  final VoidCallback onStorageFilter;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const outer = Radius.circular(26);
    const inner = Radius.circular(8);
    final storageIcon = switch (storageFilter) {
      1 => Icons.cloud_rounded,
      2 => Icons.phone_android_rounded,
      _ => Icons.dataset_rounded,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            SizedBox(
              height: 42,
              child: FilledButton.icon(
                onPressed: onMainAction,
                style: FilledButton.styleFrom(
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: colors.tertiaryContainer,
                  foregroundColor: colors.onTertiaryContainer,
                  shape: const StadiumBorder(),
                ),
                icon: Icon(
                  isPlaylist
                      ? Icons.playlist_add_rounded
                      : Icons.shuffle_rounded,
                  size: 20,
                ),
                label: Text(
                  isPlaylist ? 'New' : 'Shuffle',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showLocate) ...[
                  _LibraryActionIcon(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Locate current song',
                    onPressed: onLocate,
                    borderRadius: const BorderRadius.only(
                      topLeft: outer,
                      bottomLeft: outer,
                      topRight: inner,
                      bottomRight: inner,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (showStorageFilter) ...[
                  _LibraryActionIcon(
                    icon: storageIcon,
                    tooltip: switch (storageFilter) {
                      1 => 'Online songs',
                      2 => 'Offline songs',
                      _ => 'All songs',
                    },
                    onPressed: onStorageFilter,
                    borderRadius: BorderRadius.only(
                      topLeft: showLocate ? inner : outer,
                      bottomLeft: showLocate ? inner : outer,
                      topRight: inner,
                      bottomRight: inner,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                _LibraryActionIcon(
                  icon: Icons.sort_rounded,
                  tooltip: 'Sort options',
                  onPressed: onSort,
                  borderRadius: BorderRadius.only(
                    topLeft: showLocate || showStorageFilter ? inner : outer,
                    bottomLeft: showLocate || showStorageFilter ? inner : outer,
                    topRight: outer,
                    bottomRight: outer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryActionIcon extends StatelessWidget {
  const _LibraryActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.borderRadius,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: colors.secondaryContainer,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: colors.onSecondaryContainer, size: 22),
          ),
        ),
      ),
    );
  }
}

class _LibrarySongItem extends StatelessWidget {
  const _LibrarySongItem({
    required this.song,
    required this.queue,
    required this.selected,
    required this.selectionIndex,
    required this.selectionMode,
    required this.onToggleSelection,
    super.key,
  });

  final Song song;
  final List<Song> queue;
  final bool selected;
  final int selectionIndex;
  final bool selectionMode;
  final VoidCallback onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final current = controller.currentSong?.id == song.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? colors.secondaryContainer
            : current
            ? colors.primaryContainer
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(selected || current ? 50 : 22),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selectionMode
            ? onToggleSelection
            : () => controller.playSong(song, fromQueue: queue),
        onLongPress: onToggleSelection,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              if (selected)
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$selectionIndex',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 50,
                  height: 50,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(current ? 25 : 10),
                  ),
                  child: Artwork(
                    colors: song.colors,
                    mediaStoreId: song.mediaStoreId,
                    borderRadius: current ? 25 : 10,
                    size: 50,
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(width: 8),
                Icon(
                  controller.isPlaying
                      ? Icons.graphic_eq_rounded
                      : Icons.pause_rounded,
                  size: 18,
                  color: colors.onPrimaryContainer,
                ),
              ],
              const SizedBox(width: 12),
              if (!selectionMode)
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
                    onPressed: () => _showSongMenu(context),
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

  void _showSongMenu(BuildContext context) {
    final controller = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.skip_next_rounded),
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
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Add to playlist'),
                onTap: () {
                  Navigator.pop(context);
                  _showPlaylistPicker(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Song information'),
                subtitle: Text(
                  '${song.album} • ${song.durationLabel} • ${song.year}',
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

class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({
    required this.grid,
    required this.albumCount,
    required this.onTap,
  });

  final bool grid;
  final int albumCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 10, 8),
      child: Row(
        children: [
          Text('$albumCount albums'),
          const Spacer(),
          IconButton(
            onPressed: onTap,
            icon: Icon(
              grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
