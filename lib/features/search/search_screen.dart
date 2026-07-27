import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/services/playlist_transfer_service.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/widgets/playlist_multi_selection_sheet.dart';
import '../../shared/widgets/song_tile.dart';
import '../player/mini_player.dart';
import '../shell/player_internal_navigation_bar.dart';
import 'widgets/genre_categories_grid.dart';

enum _SearchFilter { all, songs, albums, artists, playlists }

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.onOpenAlbum,
    required this.onOpenArtist,
    required this.onOpenPlaylist,
    required this.onOpenGenre,
    required this.onOpenSettings,
    super.key,
  });

  final ValueChanged<String> onOpenAlbum;
  final ValueChanged<String> onOpenArtist;
  final ValueChanged<String> onOpenPlaylist;
  final ValueChanged<String> onOpenGenre;
  final VoidCallback onOpenSettings;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  _SearchFilter _filter = _SearchFilter.all;
  final List<Song> _selectedSongs = [];
  final List<Album> _selectedAlbums = [];
  final List<Playlist> _selectedPlaylists = [];
  final List<String> _selectedGenres = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _focusNode
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final query = _controller.text.trim().toLowerCase();
    final searching = query.isNotEmpty;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final selectionCount =
        _selectedSongs.length +
        _selectedAlbums.length +
        _selectedPlaylists.length +
        _selectedGenres.length;
    final bottomGradientHeight =
        resolveNavBarContentHeight(app.navBarCompactMode) +
        miniPlayerHeight +
        miniPlayerBottomSpacer +
        8;
    return PopScope(
      canPop: selectionCount == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectionCount > 0) {
          setState(_clearSelection);
        }
      },
      child: Stack(
        children: [
          ColoredBox(
            color: colors.surface,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SearchBar(
                            controller: _controller,
                            focusNode: _focusNode,
                            constraints: const BoxConstraints.tightFor(
                              height: 56,
                            ),
                            hintText: 'Search…',
                            onSubmitted: app.addSearchHistory,
                            leading: Icon(
                              Icons.search_rounded,
                              size: 24,
                              color: colors.primary,
                            ),
                            trailing: [
                              if (_controller.text.isNotEmpty)
                                IconButton(
                                  onPressed: _controller.clear,
                                  style: IconButton.styleFrom(
                                    fixedSize: const Size.square(48),
                                    backgroundColor: colors.primaryContainer
                                        .withValues(alpha: .2),
                                    foregroundColor: colors.primary,
                                  ),
                                  icon: const Icon(Icons.close_rounded),
                                  tooltip: 'Clear',
                                ),
                            ],
                            textStyle: WidgetStatePropertyAll(
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                            hintStyle: WidgetStatePropertyAll(
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: colors.primary,
                              ),
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            backgroundColor: WidgetStatePropertyAll(
                              colors.primaryContainer.withValues(alpha: .3),
                            ),
                            elevation: const WidgetStatePropertyAll(0),
                            surfaceTintColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: IconButton.filled(
                            onPressed: widget.onOpenSettings,
                            style: IconButton.styleFrom(
                              backgroundColor: colors.primaryContainer,
                              foregroundColor: colors.onPrimaryContainer,
                            ),
                            icon: const Icon(Icons.settings_rounded),
                            tooltip: 'Settings',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 320),
                      reverseDuration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previousChildren, ?currentChild],
                      ),
                      transitionBuilder: (child, animation) {
                        final enteringFrom = searching
                            ? const Offset(0, .1)
                            : const Offset(0, -.1);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: enteringFrom,
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: searching
                          ? _searchResultsMode(query)
                          : GenreCategoriesGrid(
                              key: const ValueKey('genre-browse-mode'),
                              genres:
                                  app.songs
                                      .map((song) => song.genre)
                                      .toSet()
                                      .toList()
                                    ..sort(
                                      (a, b) => a.toLowerCase().compareTo(
                                        b.toLowerCase(),
                                      ),
                                    ),
                              selectedGenres: _selectedGenres,
                              onGenreClick: widget.onOpenGenre,
                              onSelectionToggle: _toggleGenreSelection,
                              onSelectAll: () => setState(() {
                                _selectedGenres
                                  ..clear()
                                  ..addAll(
                                    app.songs.map((song) => song.genre).toSet(),
                                  );
                              }),
                              onClearSelection: () => setState(_clearSelection),
                              onSelectionOptions: _showSelectedGenreOptions,
                            ),
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _searchResultsMode(String query) {
    return Padding(
      key: const ValueKey('search-results-mode'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _filterBar(),
          Expanded(
            child: ClipPath(
              clipper: ShapeBorderClipper(
                shape: const RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
              ),
              child: CustomScrollView(
                key: const PageStorageKey('search-results-scroll'),
                slivers: [
                  ..._results(query),
                  SliverToBoxAdapter(
                    child: SizedBox(height: _resultsBottomPadding()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _resultsBottomPadding() {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardInset > 8) return keyboardInset;
    final controller = AppScope.of(context);
    final systemInset = sanitizeNavigationBarBottomInset(
      MediaQuery.viewPaddingOf(context).bottom,
    );
    return resolveNavBarOccupiedHeight(
          systemInset: systemInset,
          compactMode: controller.navBarCompactMode,
        ) +
        miniPlayerHeight +
        28;
  }

  Widget _filterBar() {
    final selectionCount =
        _selectedSongs.length +
        _selectedAlbums.length +
        _selectedPlaylists.length +
        _selectedGenres.length;
    if (selectionCount > 0) {
      final query = _controller.text.trim().toLowerCase();
      final app = AppScope.of(context);
      final allSongMatches = app.songs
          .where(
            (song) => _matches(query, [
              song.title,
              song.artist,
              song.album,
              song.genre,
            ]),
          )
          .toList();
      final allAlbumMatches = app.albums
          .where((album) => _matches(query, [album.title, album.artist]))
          .take(20)
          .toList();
      final allPlaylistMatches = app.playlists
          .where((playlist) => _matches(query, [playlist.name]))
          .toList();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$selectionCount selected',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => setState(() {
                if (_selectedAlbums.isNotEmpty) {
                  _selectedAlbums
                    ..clear()
                    ..addAll(allAlbumMatches);
                } else if (_selectedPlaylists.isNotEmpty) {
                  _selectedPlaylists
                    ..clear()
                    ..addAll(allPlaylistMatches);
                } else {
                  _selectedSongs
                    ..clear()
                    ..addAll(allSongMatches);
                }
              }),
              icon: const Icon(Icons.select_all_rounded),
              tooltip: 'Select all',
            ),
            IconButton.filledTonal(
              onPressed: _selectedPlaylists.isNotEmpty
                  ? _showSelectedPlaylistOptions
                  : () => _showSelectedSongOptions(_selectedActionSongs()),
              icon: const Icon(Icons.more_horiz_rounded),
              tooltip: 'Selection options',
            ),
            IconButton(
              onPressed: () => setState(_clearSelection),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Clear selection',
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          for (final filter in _SearchFilter.values)
            FilterChip(
              selected: _filter == filter,
              onSelected: (_) => setState(() => _filter = filter),
              showCheckmark: true,
              shape: const StadiumBorder(),
              side: BorderSide.none,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              selectedColor: Theme.of(context).colorScheme.primary,
              checkmarkColor: Theme.of(context).colorScheme.onPrimary,
              labelStyle: TextStyle(
                color: _filter == filter
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              label: Text(_label(filter)),
            ),
        ],
      ),
    );
  }

  List<Widget> _results(String query) {
    final controller = AppScope.of(context);
    final songs = controller.songs
        .where(
          (song) => _matches(query, [
            song.title,
            song.artist,
            song.album,
            song.genre,
          ]),
        )
        .toList();
    final albums = controller.albums
        .where((album) => _matches(query, [album.title, album.artist]))
        .toList();
    final artists = controller.artists
        .where((artist) => _matches(query, [artist.name]))
        .toList();
    final playlists = controller.playlists
        .where((playlist) => _matches(query, [playlist.name]))
        .toList();
    final nothing =
        (!_shows(_SearchFilter.songs) || songs.isEmpty) &&
        (!_shows(_SearchFilter.albums) || albums.isEmpty) &&
        (!_shows(_SearchFilter.artists) || artists.isEmpty) &&
        (!_shows(_SearchFilter.playlists) || playlists.isEmpty);
    if (nothing) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyResults(query: _controller.text),
        ),
      ];
    }

    return [
      if (_shows(_SearchFilter.songs) && songs.isNotEmpty) ...[
        const SliverToBoxAdapter(child: _ResultHeader('Songs')),
        SliverList.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final selectionIndex = _selectedSongs.indexWhere(
              (selected) => selected.id == song.id,
            );
            final selected = selectionIndex >= 0;
            return SongTile(
              song: song,
              queue: songs,
              selected: selected,
              selectionIndex: selected ? selectionIndex + 1 : null,
              onLongPress: () => _toggleSongSelection(song),
              onTap: _selectedSongs.isEmpty
                  ? null
                  : () => _toggleSongSelection(song),
            );
          },
        ),
      ],
      if (_shows(_SearchFilter.albums) && albums.isNotEmpty) ...[
        const SliverToBoxAdapter(child: _ResultHeader('Albums')),
        SliverToBoxAdapter(
          child: _HorizontalResults(
            items: [
              for (final album in albums)
                _ResultCard(
                  title: album.title,
                  subtitle: album.artist,
                  colors: album.colors,
                  mediaStoreId: album.songs.first.mediaStoreId,
                  selected: _selectedAlbums.any(
                    (selected) => selected.id == album.id,
                  ),
                  onTap: () => _selectedAlbums.isNotEmpty
                      ? _toggleAlbumSelection(album)
                      : widget.onOpenAlbum(album.id),
                  onLongPress: () => _toggleAlbumSelection(album),
                ),
            ],
          ),
        ),
      ],
      if (_shows(_SearchFilter.artists) && artists.isNotEmpty) ...[
        const SliverToBoxAdapter(child: _ResultHeader('Artists')),
        SliverList.builder(
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: ClipOval(
                child: Artwork(
                  colors: artist.colors,
                  size: 58,
                  borderRadius: 0,
                  mediaStoreId: artist.songs.first.mediaStoreId,
                ),
              ),
              title: Text(artist.name),
              subtitle: Text('${artist.songs.length} songs'),
              trailing: const Icon(Icons.arrow_forward_rounded),
              onTap: () => widget.onOpenArtist(artist.id),
            );
          },
        ),
      ],
      if (_shows(_SearchFilter.playlists) && playlists.isNotEmpty) ...[
        const SliverToBoxAdapter(child: _ResultHeader('Playlists')),
        SliverList.builder(
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            final selected = _selectedPlaylists.any(
              (item) => item.id == playlist.id,
            );
            return ListTile(
              selected: selected,
              selectedTileColor: Theme.of(
                context,
              ).colorScheme.secondaryContainer,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: PlaylistCover(playlist: playlist, size: 52),
              title: Text(playlist.name),
              subtitle: Text('${playlist.songs.length} songs'),
              trailing: selected
                  ? const Icon(Icons.check_circle_rounded)
                  : null,
              onTap: () => _selectedPlaylists.isNotEmpty
                  ? _togglePlaylistSelection(playlist)
                  : widget.onOpenPlaylist(playlist.id),
              onLongPress: () => _togglePlaylistSelection(playlist),
            );
          },
        ),
      ],
    ];
  }

  void _toggleSongSelection(Song song) {
    setState(() {
      _selectedAlbums.clear();
      _selectedPlaylists.clear();
      _selectedGenres.clear();
      final index = _selectedSongs.indexWhere((item) => item.id == song.id);
      index < 0 ? _selectedSongs.add(song) : _selectedSongs.removeAt(index);
    });
  }

  void _toggleAlbumSelection(Album album) {
    setState(() {
      _selectedSongs.clear();
      _selectedPlaylists.clear();
      _selectedGenres.clear();
      final index = _selectedAlbums.indexWhere((item) => item.id == album.id);
      if (index >= 0) {
        _selectedAlbums.removeAt(index);
      } else if (_selectedAlbums.length < 20) {
        _selectedAlbums.add(album);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can select up to 20 albums.')),
        );
      }
    });
  }

  void _togglePlaylistSelection(Playlist playlist) {
    setState(() {
      _selectedSongs.clear();
      _selectedAlbums.clear();
      _selectedGenres.clear();
      final index = _selectedPlaylists.indexWhere(
        (item) => item.id == playlist.id,
      );
      index >= 0
          ? _selectedPlaylists.removeAt(index)
          : _selectedPlaylists.add(playlist);
    });
  }

  void _toggleGenreSelection(String genre) {
    setState(() {
      _selectedSongs.clear();
      _selectedAlbums.clear();
      _selectedPlaylists.clear();
      _selectedGenres.contains(genre)
          ? _selectedGenres.remove(genre)
          : _selectedGenres.add(genre);
    });
  }

  void _clearSelection() {
    _selectedSongs.clear();
    _selectedAlbums.clear();
    _selectedPlaylists.clear();
    _selectedGenres.clear();
  }

  List<Song> _selectedActionSongs() {
    final candidates = _selectedAlbums.isNotEmpty
        ? _selectedAlbums.expand((album) => album.songs)
        : _selectedGenres.isNotEmpty
        ? AppScope.of(
            context,
          ).songs.where((song) => _selectedGenres.contains(song.genre))
        : _selectedSongs;
    final byId = <String, Song>{};
    for (final song in candidates) {
      byId.putIfAbsent(song.id, () => song);
    }
    return byId.values.toList(growable: false);
  }

  void _showSelectedGenreOptions() {
    final selectedGenres = List<String>.of(_selectedGenres);
    if (selectedGenres.isEmpty) return;
    final controller = AppScope.of(context);
    final selectedSongs = controller.songs
        .where((song) => selectedGenres.contains(song.genre))
        .toList(growable: false);
    if (selectedSongs.isEmpty) return;
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
                  '${selectedGenres.length} genres selected',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text('${selectedSongs.length} songs'),
              ),
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('Play selected'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.playSong(
                    selectedSongs.first,
                    fromQueue: selectedSongs,
                  );
                  setState(_clearSelection);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded),
                title: const Text('Play next'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  for (final song in selectedSongs.reversed) {
                    controller.addSongNextToQueue(song);
                  }
                  setState(_clearSelection);
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: const Text('Add to queue'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  for (final song in selectedSongs) {
                    controller.addSongToQueue(song);
                  }
                  setState(_clearSelection);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Add to playlist'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showPlaylistPicker(selectedSongs);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectedSongOptions(List<Song> selected) {
    if (selected.isEmpty) return;
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
                  _showPlaylistPicker(selected);
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

  void _showSelectedPlaylistOptions() {
    final selected = List<Playlist>.of(_selectedPlaylists);
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
      if (count == null) return;
      if (!mounted) return;
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

  void _showPlaylistPicker(List<Song> selected) {
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

  bool _shows(_SearchFilter filter) =>
      _filter == _SearchFilter.all || _filter == filter;

  bool _matches(String query, List<String> values) {
    return values.any((value) => value.toLowerCase().contains(query));
  }

  String _label(_SearchFilter filter) => switch (filter) {
    _SearchFilter.all => 'All',
    _SearchFilter.songs => 'Songs',
    _SearchFilter.albums => 'Albums',
    _SearchFilter.artists => 'Artists',
    _SearchFilter.playlists => 'Playlists',
  };
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}

class _HorizontalResults extends StatelessWidget {
  const _HorizontalResults({required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 205,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.subtitle,
    required this.colors,
    this.mediaStoreId,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
  final int? mediaStoreId;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 144,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(selected ? 4 : 0),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(selected ? 24 : 18),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(selected ? 20 : 18),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Artwork(
                    colors: colors,
                    size: selected ? 136 : 144,
                    borderRadius: selected ? 20 : 18,
                    mediaStoreId: mediaStoreId,
                  ),
                  if (selected)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(Icons.check_circle_rounded, size: 30),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 86,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 18),
            Text(
              'No results for “$query”',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search or change the filters.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
