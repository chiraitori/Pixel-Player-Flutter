import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/song.dart';
import '../../core/services/playlist_transfer_service.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/widgets/playlist_multi_selection_sheet.dart';
import '../../shared/widgets/song_tile.dart';
import '../player/mini_player.dart';
import '../player/song_info_bottom_sheet.dart';
import '../shell/player_internal_navigation_bar.dart';
import 'widgets/library_empty_state.dart';
import 'widgets/folder_breadcrumb.dart';
import 'widgets/tab_animation.dart';

double _libraryContentBottomPadding(BuildContext context) {
  final controller = AppScope.of(context);
  final systemInset = sanitizeNavigationBarBottomInset(
    MediaQuery.viewPaddingOf(context).bottom,
  );
  return resolveNavBarOccupiedHeight(
        systemInset: systemInset,
        compactMode: controller.navBarCompactMode,
      ) +
      miniPlayerHeight +
      30;
}

enum LibrarySection {
  songs('Songs', Icons.music_note_rounded),
  albums('Albums', Icons.album_rounded),
  artists('Artists', Icons.person_rounded),
  playlists('Playlists', Icons.queue_music_rounded),
  folders('Folders', Icons.folder_rounded),
  favorites('Liked', Icons.favorite_rounded);

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
  List<LibrarySection> _sectionOrder = List.of(LibrarySection.values);
  bool _sectionOrderLoaded = false;
  bool _grid = true;
  bool _foldersPlaylistView = false;
  String? _currentFolderPath;
  final Map<LibrarySection, String> _sortBySection = {
    for (final section in LibrarySection.values) section: 'Title',
  };
  final Map<LibrarySection, bool> _sortDescendingBySection = {
    for (final section in LibrarySection.values) section: false,
  };
  int _storageFilter = 0;
  final List<Song> _selectedSongs = [];
  final Set<String> _selectedMediaIds = {};

  String get _sort => _sortBySection[_section] ?? 'Title';

  bool get _sortDescending => _sortDescendingBySection[_section] ?? false;

  List<String> get _sortOptions => switch (_section) {
    LibrarySection.songs || LibrarySection.favorites => const [
      'Title',
      'Artist',
      'Album',
      'Date added',
      'Duration',
    ],
    LibrarySection.albums => const ['Title', 'Artist', 'Year', 'Date added'],
    LibrarySection.artists => const ['Name', 'Song count'],
    LibrarySection.playlists => const ['Title'],
    LibrarySection.folders => const ['Name', 'Song count'],
  };

  bool _defaultSortDescending(String option) => option == 'Date added';

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sectionOrderLoaded) return;
    _sectionOrderLoaded = true;
    final saved = AppScope.of(context).stringListSetting(
      'library_tab_order',
      LibrarySection.values.map((section) => section.name).toList(),
    );
    final restored = <LibrarySection>[
      for (final name in saved)
        ...LibrarySection.values.where((section) => section.name == name),
      for (final section in LibrarySection.values)
        if (!saved.contains(section.name)) section,
    ];
    _sectionOrder = restored.toSet().toList(growable: false);
    final controller = AppScope.of(context);
    for (final section in LibrarySection.values) {
      _sortBySection[section] = controller.stringSetting(
        'library_sort_${section.name}',
        'Title',
      );
      final savedDirection = controller.stringSetting(
        'library_sort_desc_${section.name}',
        '',
      );
      _sortDescendingBySection[section] = switch (savedDirection) {
        'true' => true,
        'false' => false,
        _ => _defaultSortDescending(_sortBySection[section]!),
      };
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pages.jumpToPage(_sectionOrder.indexOf(_section));
    });
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
    int applyDirection(int comparison) =>
        _sortDescending ? -comparison : comparison;
    switch (_sort) {
      case 'Artist':
        albums.sort(
          (a, b) => applyDirection(
            a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
          ),
        );
        artists.sort(
          (a, b) => applyDirection(
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
        );
        break;
      case 'Date added':
        albums.sort(
          (a, b) => applyDirection(
            (a.songs.first.dateAdded ?? DateTime(0)).compareTo(
              b.songs.first.dateAdded ?? DateTime(0),
            ),
          ),
        );
        break;
      case 'Year':
        albums.sort(
          (a, b) => applyDirection(
            (a.songs.firstOrNull?.year ?? 0).compareTo(
              b.songs.firstOrNull?.year ?? 0,
            ),
          ),
        );
        break;
      case 'Song count':
        artists.sort(
          (a, b) => applyDirection(a.songs.length.compareTo(b.songs.length)),
        );
        break;
      default:
        albums.sort(
          (a, b) => applyDirection(
            a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          ),
        );
        artists.sort(
          (a, b) => applyDirection(
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
        );
        playlists.sort(
          (a, b) => applyDirection(
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
        );
        break;
    }
    final favoriteSongs = _sortedSongs(
      controller.favoriteSongs.where(_matchesStorageFilter).toList(),
    );
    final colors = Theme.of(context).colorScheme;
    final compact = controller.libraryCompactMode;
    final bottomGradientHeight =
        resolveNavBarContentHeight(controller.navBarCompactMode) +
        miniPlayerHeight +
        miniPlayerBottomSpacer +
        8;
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
      child: Stack(
        children: [
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: _LibraryHeader(
                  section: _section,
                  sectionOrder: _sectionOrder,
                  compact: compact,
                  onOpenSettings: widget.onOpenSettings,
                  onOpenSections: () => _showSectionPicker(context),
                  onSelectSection: (section) {
                    _pages.animateToPage(
                      _sectionOrder.indexOf(section),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: colors.primaryContainer.withValues(alpha: .4),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(34),
                    ),
                    child: ColoredBox(
                      color: colors.surface,
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
                              onOptions: () =>
                                  _section == LibrarySection.playlists
                                  ? _showSelectedPlaylistOptions(
                                      selectedPlaylists,
                                    )
                                  : _showSelectedSongOptions(
                                      selectedActionSongs,
                                    ),
                              onClear: () => setState(_clearSelection),
                            )
                          else
                            _LibraryActionRow(
                              isPlaylist: _section == LibrarySection.playlists,
                              isFolderBreadcrumb:
                                  _section == LibrarySection.folders &&
                                  (!_foldersPlaylistView ||
                                      _currentFolderPath != null),
                              folderPath: _currentFolderPath,
                              onFolderBack: () => setState(() {
                                final current = _currentFolderPath;
                                if (current == null) return;
                                final parent = current.lastIndexOf('/');
                                _currentFolderPath = parent < 0
                                    ? null
                                    : current.substring(0, parent);
                              }),
                              showLocate: locateVisible,
                              showStorageFilter: switch (_section) {
                                LibrarySection.songs ||
                                LibrarySection.albums ||
                                LibrarySection.artists ||
                                LibrarySection.favorites => true,
                                _ => false,
                              },
                              storageFilter: _storageFilter,
                              onMainAction: () => _runMainAction(
                                controller,
                                songs,
                                favoriteSongs,
                              ),
                              onImportM3u: _section == LibrarySection.playlists
                                  ? () => _importM3u(controller)
                                  : null,
                              onLocate: () =>
                                  _locateCurrentSong(controller, songs),
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
                                  _section = _sectionOrder[index];
                                  _clearSelection();
                                });
                              },
                              children: () {
                                final pages = <LibrarySection, Widget>{
                                  LibrarySection.songs: _SongsTab(
                                    songs: songs,
                                    controller: _songsScroll,
                                    selectedSongs: _selectedSongs,
                                    onToggleSelection: _toggleSongSelection,
                                  ),
                                  LibrarySection.albums: _AlbumsTab(
                                    albums: albums,
                                    grid: _grid,
                                    selectedIds: _selectedMediaIds,
                                    onOpen: widget.onOpenAlbum,
                                    onToggleSelection: _toggleMediaSelection,
                                  ),
                                  LibrarySection.artists: _ArtistsTab(
                                    artists: artists,
                                    onOpen: widget.onOpenArtist,
                                  ),
                                  LibrarySection.playlists: _PlaylistsTab(
                                    playlists: playlists,
                                    selectedIds: _selectedMediaIds,
                                    onOpen: widget.onOpenPlaylist,
                                    onToggleSelection: _toggleMediaSelection,
                                    onCreate: widget.onCreatePlaylist,
                                  ),
                                  LibrarySection.folders: _FoldersTab(
                                    songs: songs,
                                    playlistView: _foldersPlaylistView,
                                    onPlaylistViewChanged: (value) => setState(
                                      () => _foldersPlaylistView = value,
                                    ),
                                    sort: _sort,
                                    descending: _sortDescending,
                                    currentDirectory: _currentFolderPath,
                                    onDirectoryChanged: (value) => setState(
                                      () => _currentFolderPath = value,
                                    ),
                                  ),
                                  LibrarySection.favorites: _SongsTab(
                                    songs: favoriteSongs,
                                    controller: _favoritesScroll,
                                    selectedSongs: _selectedSongs,
                                    onToggleSelection: _toggleSongSelection,
                                    emptyIcon: Icons.favorite_rounded,
                                    emptyTitle: 'No liked songs yet',
                                    emptySubtitle:
                                        'Tap the heart icon while playing a song to save it here.',
                                  ),
                                };
                                return _sectionOrder
                                    .map((section) => pages[section]!)
                                    .toList(growable: false);
                              }(),
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomGradientHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .2, .8, 1],
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      colors.surfaceContainerLowest,
                      colors.surfaceContainerLowest,
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

  Future<void> _importM3u(AppController controller) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['m3u', 'm3u8'],
      dialogTitle: 'Import M3U playlist',
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return;

    try {
      final bytes = file.bytes;
      if (bytes == null) throw StateError('The selected playlist has no data');
      final contents = utf8.decode(bytes);
      final imported = PlaylistTransferService.parseM3u(
        contents,
        fileName: file.name,
        library: controller.songs,
      );
      if (imported.songIds.isEmpty || !mounted) return;
      controller.createPlaylist(imported.name, imported.songIds);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${imported.songIds.length} song${imported.songIds.length == 1 ? '' : 's'}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not import that M3U playlist')),
      );
    }
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
          child: SingleChildScrollView(
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
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: const Text('Share selected'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareSelectedSongs(selected);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareSelectedSongs(List<Song> selected) async {
    final preview = selected
        .take(4)
        .map((song) => '${song.title} — ${song.artist}')
        .join('\n');
    final suffix = selected.length > 4
        ? '\n… and ${selected.length - 4} more'
        : '';
    await SharePlus.instance.share(
      ShareParams(
        title: '${selected.length} selected songs',
        text: '$preview$suffix',
      ),
    );
    if (mounted) setState(_clearSelection);
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
        child: SingleChildScrollView(
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showTabReorderSheet(context),
                    icon: const Icon(Icons.drag_handle_rounded),
                    label: const Text('Reorder tabs'),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.05,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _sectionOrder.length,
                  itemBuilder: (context, index) {
                    final section = _sectionOrder[index];
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
      ),
    );
  }

  Future<void> _showTabReorderSheet(BuildContext context) async {
    final order = List<LibrarySection>.of(_sectionOrder);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SizedBox(
          height: 430,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Reorder library tabs',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: order.length,
                  onReorderItem: (oldIndex, newIndex) => setSheetState(() {
                    final item = order.removeAt(oldIndex);
                    order.insert(newIndex, item);
                  }),
                  itemBuilder: (context, index) {
                    final section = order[index];
                    return ListTile(
                      key: ValueKey(section),
                      leading: Icon(section.icon),
                      title: Text(section.label),
                      trailing: const Icon(Icons.drag_handle_rounded),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => setSheetState(() {
                        order
                          ..clear()
                          ..addAll(LibrarySection.values);
                      }),
                      child: const Text('Reset'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        final controller = AppScope.of(this.context);
                        setState(() => _sectionOrder = List.of(order));
                        controller.setStringListSetting(
                          'library_tab_order',
                          order.map((section) => section.name),
                        );
                        _pages.jumpToPage(_sectionOrder.indexOf(_section));
                        Navigator.pop(context);
                      },
                      child: const Text('Done'),
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

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 26),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      'Sort ${_section.label.toLowerCase()}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Material(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      leading: Icon(
                        _sortDescending
                            ? Icons.south_rounded
                            : Icons.north_rounded,
                      ),
                      title: Text(_sortDescending ? 'Descending' : 'Ascending'),
                      subtitle: Text(
                        _sortDescending
                            ? 'Tap to sort ascending'
                            : 'Tap to sort descending',
                      ),
                      onTap: () {
                        final section = _section;
                        final next = !_sortDescending;
                        setState(
                          () => _sortDescendingBySection[section] = next,
                        );
                        setModalState(() {});
                        AppScope.of(this.context).setStringSetting(
                          'library_sort_desc_${section.name}',
                          '$next',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: _sort,
                    onChanged: (value) {
                      if (value != null) {
                        final section = _section;
                        setState(() => _sortBySection[section] = value);
                        final controller = AppScope.of(this.context);
                        controller.setStringSetting(
                          'library_sort_${section.name}',
                          value,
                        );
                      }
                      Navigator.pop(context);
                    },
                    child: Column(
                      children: [
                        for (final option in _sortOptions)
                          RadioListTile<String>(
                            value: option,
                            title: Text(option),
                          ),
                      ],
                    ),
                  ),
                  if (_section == LibrarySection.albums) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 8),
                        child: Text(
                          'View',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: true,
                            icon: Icon(Icons.view_module_rounded),
                            label: Text('Grid'),
                          ),
                          ButtonSegment<bool>(
                            value: false,
                            icon: Icon(Icons.view_list_rounded),
                            label: Text('List'),
                          ),
                        ],
                        selected: {_grid},
                        onSelectionChanged: (selection) {
                          setState(() => _grid = selection.first);
                        },
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(32),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_section == LibrarySection.folders) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 8),
                        child: Text(
                          'View',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    Material(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      child: SwitchListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text('Playlist view'),
                        subtitle: const Text(
                          'Show folders as playable artwork cards',
                        ),
                        value: _foldersPlaylistView,
                        onChanged: (value) {
                          setState(() => _foldersPlaylistView = value);
                          setModalState(() {});
                        },
                      ),
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
          (a, b) => (a.dateAdded ?? DateTime(0)).compareTo(
            b.dateAdded ?? DateTime(0),
          ),
        );
        break;
      case 'Duration':
        sorted.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      default:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
    }
    if (_sortDescending) return sorted.reversed.toList(growable: false);
    return sorted;
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.section,
    required this.sectionOrder,
    required this.compact,
    required this.onOpenSettings,
    required this.onOpenSections,
    required this.onSelectSection,
  });

  final LibrarySection section;
  final List<LibrarySection> sectionOrder;
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
              // CompactLibraryPagerIndicator in LibraryScreen.kt uses an
              // 8dp top / 10dp bottom inset. Keeping the same 22dp strip
              // prevents the rounded content surface from starting 8dp too
              // low below the page dots.
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final item in sectionOrder)
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
                  for (final item in sectionOrder)
                    _LibraryTabButton(
                      section: item,
                      index: sectionOrder.indexOf(item),
                      selectedIndex: sectionOrder.indexOf(section),
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
                                // Match LibraryNavigationPill's non-compressed
                                // Compose style. Without this explicit width
                                // axis, Flutter rendered the section title much
                                // narrower than the Kotlin "Songs" pill.
                                fontVariations: const [
                                  ui.FontVariation('wght', 400),
                                  ui.FontVariation('wdth', 100),
                                  ui.FontVariation('ROND', 100),
                                  ui.FontVariation('XTRA', 520),
                                  ui.FontVariation('YOPQ', 90),
                                  ui.FontVariation('YTLC', 505),
                                ],
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
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        _libraryContentBottomPadding(context),
      ),
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
  });

  final List<Album> albums;
  final bool grid;
  final Set<String> selectedIds;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onToggleSelection;

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
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          _libraryContentBottomPadding(context) + 4,
        ),
        itemCount: albums.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final album = albums[index];
          final selected = selectedIds.contains(album.id);
          return _AlbumListCard(
            album: album,
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
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        _libraryContentBottomPadding(context) + 4,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        // Kotlin uses 3:2 artwork plus an 84dp metadata panel.
        childAspectRatio: .84,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        final selected = selectedIds.contains(album.id);
        return _AlbumGridCard(
          album: album,
          selected: selected,
          selectionMode: selectedIds.isNotEmpty,
          onTap: () => selectedIds.isNotEmpty
              ? onToggleSelection(album.id)
              : onOpen(album.id),
          onLongPress: () => onToggleSelection(album.id),
        );
      },
    );
  }
}

ColorScheme _albumColorScheme(BuildContext context, Album album) {
  final seed = album.colors.isEmpty
      ? Theme.of(context).colorScheme.primary
      : album.colors.first;
  return ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Theme.of(context).brightness,
  );
}

class _AlbumGridCard extends StatelessWidget {
  const _AlbumGridCard({
    required this.album,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  final Album album;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = _albumColorScheme(context, album);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? .985 : 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.fastOutSlowIn,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Material(
        key: ValueKey('album-grid-${album.id}'),
        color: colors.surfaceContainerHighest.withValues(alpha: .3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: selected
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 3 / 2,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Artwork(
                          colors: album.colors,
                          borderRadius: 0,
                          mediaStoreId: album.songs.first.mediaStoreId,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                colors.primaryContainer,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _AlbumMetadata(album: album, colors: colors),
                ],
              ),
              if (selectionMode && selected)
                const Positioned(
                  top: 10,
                  right: 10,
                  child: _MediaSelectionBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumListCard extends StatelessWidget {
  const _AlbumListCard({
    required this.album,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    Object? selectedTileColor,
    Object? contentPadding,
    Object? leading,
    Object? title,
    Object? subtitle,
    Object? trailing,
  });

  final Album album;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = _albumColorScheme(context, album);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? .99 : 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.fastOutSlowIn,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: SizedBox(
        height: 88,
        child: Material(
          key: ValueKey('album-list-${album.id}'),
          color: colors.surfaceContainerHighest.withValues(alpha: .3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: selected
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 88,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Artwork(
                            colors: album.colors,
                            borderRadius: 0,
                            mediaStoreId: album.songs.first.mediaStoreId,
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  colors.primaryContainer,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _AlbumMetadata(
                        album: album,
                        colors: colors,
                        list: true,
                      ),
                    ),
                  ],
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
        ),
      ),
    );
  }
}

class _AlbumMetadata extends StatelessWidget {
  const _AlbumMetadata({
    required this.album,
    required this.colors,
    this.list = false,
  });

  final Album album;
  final ColorScheme colors;
  final bool list;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      color: colors.primaryContainer,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (list
                        ? Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(fontSize: 22)
                        : Theme.of(context).textTheme.titleMedium)
                    ?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: list ? null : FontWeight.bold,
                    ),
          ),
          if (list) const SizedBox(height: 4),
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onPrimaryContainer.withValues(alpha: .85),
            ),
          ),
          Text(
            '${album.songs.length} songs',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onPrimaryContainer.withValues(alpha: .7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistsTab extends StatelessWidget {
  const _ArtistsTab({required this.artists, required this.onOpen});

  final List<Artist> artists;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.person_rounded,
        title: 'No artists available',
        subtitle: 'Artists are shown after songs are indexed from any source.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        12,
        4,
        12,
        _libraryContentBottomPadding(context),
      ),
      itemCount: artists.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final artist = artists[index];
        return Card(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onOpen(artist.id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipOval(
                    child: Artwork(
                      colors: artist.colors,
                      size: 48,
                      borderRadius: 0,
                      mediaStoreId: artist.songs.first.mediaStoreId,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${artist.songs.length} songs',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        _libraryContentBottomPadding(context),
      ),
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

class _FoldersTab extends StatefulWidget {
  const _FoldersTab({
    required this.songs,
    required this.playlistView,
    required this.onPlaylistViewChanged,
    required this.sort,
    required this.descending,
    required this.currentDirectory,
    required this.onDirectoryChanged,
  });

  final List<Song> songs;
  final bool playlistView;
  final ValueChanged<bool> onPlaylistViewChanged;
  final String sort;
  final bool descending;
  final String? currentDirectory;
  final ValueChanged<String?> onDirectoryChanged;

  @override
  State<_FoldersTab> createState() => _FoldersTabState();
}

class _FoldersTabState extends State<_FoldersTab> {
  @override
  Widget build(BuildContext context) {
    final directories = <String, List<Song>>{};
    for (final song in widget.songs) {
      final path = song.path;
      if (path == null) continue;
      final normalized = path.replaceAll('\\', '/');
      final separator = normalized.lastIndexOf('/');
      if (separator < 1) continue;
      final directory = normalized
          .substring(0, separator)
          .replaceFirst(RegExp(r'^/+'), '');
      directories.putIfAbsent(directory, () => []).add(song);
    }
    if (directories.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.folder_rounded,
        title: 'No folders found',
        subtitle: 'Internal storage folders with music will appear here.',
      );
    }
    final current = widget.currentDirectory;
    final directSongs = [...(directories[current] ?? const <Song>[])];
    final children = <String, List<Song>>{};
    for (final entry in directories.entries) {
      final path = entry.key;
      final prefix = current == null ? '' : '$current/';
      if (current != null && !path.startsWith(prefix)) continue;
      final remainder = current == null ? path : path.substring(prefix.length);
      final separator = remainder.indexOf('/');
      final name = separator < 0
          ? remainder
          : remainder.substring(0, separator);
      final childPath = current == null ? name : '$current/$name';
      children.putIfAbsent(childPath, () => []).addAll(entry.value);
    }
    final folders = children.entries.toList()
      ..sort((a, b) {
        final comparison = widget.sort == 'Song count'
            ? a.value.length.compareTo(b.value.length)
            : a.key.toLowerCase().compareTo(b.key.toLowerCase());
        return widget.descending ? -comparison : comparison;
      });
    directSongs.sort((a, b) {
      final comparison = switch (widget.sort) {
        'Artist' => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
        'Album' => a.album.toLowerCase().compareTo(b.album.toLowerCase()),
        'Date added' => (a.dateAdded ?? DateTime(0)).compareTo(
          b.dateAdded ?? DateTime(0),
        ),
        'Duration' => a.duration.compareTo(b.duration),
        _ => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      };
      return widget.descending ? -comparison : comparison;
    });
    final queue = [...directSongs, ...folders.expand((entry) => entry.value)];
    if (widget.playlistView && current == null) {
      return Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                _libraryContentBottomPadding(context),
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .92,
              ),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                final name = folder.key.substring(
                  folder.key.lastIndexOf('/') + 1,
                );
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => AppScope.of(
                      context,
                    ).playSong(folder.value.first, fromQueue: folder.value),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) => Artwork(
                                colors: folder.value.first.colors,
                                size: constraints.biggest.shortestSide,
                                borderRadius: 18,
                                mediaStoreId: folder.value.first.mediaStoreId,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text('${folder.value.length} songs'),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: ListView.builder(
        key: ValueKey(current),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          _libraryContentBottomPadding(context),
        ),
        itemCount: folders.length + directSongs.length,
        itemBuilder: (context, index) {
          if (index >= folders.length) {
            return Material(
              color: Colors.transparent,
              child: SongTile(
                song: directSongs[index - folders.length],
                queue: queue,
              ),
            );
          }
          final folder = folders[index];
          final name = folder.key.substring(folder.key.lastIndexOf('/') + 1);
          return Card(
            child: ListTile(
              leading: const Icon(Icons.folder_rounded, size: 36),
              title: Text(name),
              subtitle: Text('${folder.value.length} songs'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => widget.onDirectoryChanged(folder.key),
            ),
          );
        },
      ),
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
    required this.isFolderBreadcrumb,
    required this.folderPath,
    required this.onFolderBack,
    required this.showLocate,
    required this.showStorageFilter,
    required this.storageFilter,
    required this.onMainAction,
    required this.onImportM3u,
    required this.onLocate,
    required this.onStorageFilter,
    required this.onSort,
  });

  final bool isPlaylist;
  final bool isFolderBreadcrumb;
  final String? folderPath;
  final VoidCallback onFolderBack;
  final bool showLocate;
  final bool showStorageFilter;
  final int storageFilter;
  final VoidCallback onMainAction;
  final VoidCallback? onImportM3u;
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
            if (isFolderBreadcrumb)
              Expanded(
                child: FolderBreadcrumb(path: folderPath, onBack: onFolderBack),
              )
            else
              SizedBox(
                height: 42,
                child: FilledButton.icon(
                  onPressed: onMainAction,
                  style: FilledButton.styleFrom(
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: colors.tertiaryContainer,
                    foregroundColor: colors.onTertiaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: outer,
                        bottomLeft: outer,
                        topRight: onImportM3u == null ? outer : inner,
                        bottomRight: onImportM3u == null ? outer : inner,
                      ),
                    ),
                  ),
                  icon: Icon(
                    isPlaylist
                        ? Icons.playlist_add_rounded
                        : Icons.shuffle_rounded,
                    size: 20,
                  ),
                  label: Text(
                    isPlaylist ? 'New' : 'Shuffle',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            if (!isFolderBreadcrumb && onImportM3u != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: FilledButton.icon(
                  onPressed: onImportM3u,
                  style: FilledButton.styleFrom(
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: colors.secondaryContainer,
                    foregroundColor: colors.onSecondaryContainer,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: inner,
                        bottomLeft: inner,
                        topRight: outer,
                        bottomRight: outer,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 20),
                  label: Text(
                    'Import',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
            if (!isFolderBreadcrumb)
              const Spacer()
            else
              const SizedBox(width: 8),
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
    return SongTile(
      song: song,
      queue: queue,
      selected: selected,
      selectionIndex: selectionIndex,
      onTap: selectionMode ? onToggleSelection : null,
      onLongPress: onToggleSelection,
      onMore: () => _showSongMenu(context),
    );
  }

  void _showSongMenu(BuildContext context) {
    // Kotlin's AlbumDetailScreen opens SongInfoBottomSheet directly from ⋮.
    // The fallback below only remains for a context that was unmounted while
    // processing the tap.
    if (context.mounted) {
      showSongInfoBottomSheet(context: context, song: song);
      return;
    }
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
                onTap: () {
                  Navigator.pop(context);
                  showSongInfoBottomSheet(context: context, song: song);
                },
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
