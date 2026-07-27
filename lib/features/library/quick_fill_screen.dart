import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../shared/widgets/artwork.dart';
import '../search/widgets/genre_icon_provider.dart';

typedef QuickFillApply =
    Future<String?> Function(List<Song> songs, String genre);

class QuickFillDialog extends StatefulWidget {
  const QuickFillDialog({
    required this.songs,
    required this.onApply,
    this.customGenres = const {},
    this.customGenreIcons = const {},
    this.onAddCustomGenre,
    super.key,
  });

  final List<Song> songs;
  final Set<String> customGenres;
  final Map<String, IconData> customGenreIcons;
  final ValueChanged<(String, IconData)>? onAddCustomGenre;
  final QuickFillApply onApply;

  @override
  State<QuickFillDialog> createState() => _QuickFillDialogState();
}

class _QuickFillDialogState extends State<QuickFillDialog> {
  static const _defaultGenres = <String>[
    'Rock',
    'Pop',
    'Jazz',
    'Classical',
    'Electronic',
    'Hip Hop',
    'Country',
    'Blues',
    'Reggae',
    'Metal',
    'Folk',
    'R&B',
    'Punk',
    'Indie',
    'Alternative',
    'Latino',
    'Reggaeton',
    'Salsa',
    'Bachata',
    'Merengue',
    'Cumbia',
    'Oldies',
    'Soundtrack',
    'Gaming',
    'Sleep',
    'Workout',
    'Party',
    'Focus',
    'Gospel',
    "Children's",
    'World',
    'Dance',
    'New Age',
    'Easy Listening',
    'Afrobeats',
    'Synthwave',
    'Drum and Bass',
    'Lo-fi',
    'Phonk',
    'Anime',
    'Balada',
    'Sertanejo',
    'Forró',
    'Tango',
    'Norteño',
    'Música Tropical',
    'Schlager',
    'Chanson',
    'Enka',
    'Trot',
  ];

  final _selectedSongIds = <String>{};
  final _search = TextEditingController();
  late final Set<String> _customGenres;
  late final Map<String, IconData> _customIcons;
  int _step = 0;
  String? _selectedGenre;
  bool _applying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _customGenres = {...widget.customGenres};
    _customIcons = {...widget.customGenreIcons};
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _step == 0 && !_applying,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _step > 0 && !_applying) {
          setState(() => _step = 0);
        }
      },
      child: Dialog.fullscreen(
        backgroundColor: colors.surface,
        child: Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            centerTitle: true,
            backgroundColor: colors.surface,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton.filled(
                onPressed: _applying
                    ? null
                    : () {
                        if (_step > 0) {
                          setState(() {
                            _step = 0;
                            _error = null;
                          });
                        } else {
                          Navigator.pop(context);
                        }
                      },
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceContainerHighest,
                  foregroundColor: colors.onSurface,
                ),
                icon: Icon(
                  _step > 0 ? Icons.arrow_back_rounded : Icons.close_rounded,
                ),
              ),
            ),
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                _step == 0 ? 'Select songs' : 'Choose genre',
                key: ValueKey(_step),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: .2,
                ),
              ),
            ),
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, animation) {
                    final enteringFromRight = _step == 1;
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: Offset(enteringFromRight ? 1 : -1, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    );
                  },
                  child: _step == 0 ? _songSelection() : _genreSelection(),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
                child: _dockedToolbar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _songSelection() {
    final colors = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final songs = widget.songs
        .where(
          (song) =>
              query.isEmpty ||
              song.title.toLowerCase().contains(query) ||
              song.artist.toLowerCase().contains(query),
        )
        .toList(growable: false);
    return Column(
      key: const ValueKey('quick-fill-songs'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search songs',
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: songs.isEmpty
              ? const Center(child: Text('No matching songs'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 116),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final selected = _selectedSongIds.contains(song.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (_) => _toggleSong(song.id),
                      controlAffinity: ListTileControlAffinity.trailing,
                      secondary: ClipOval(
                        child: Artwork(
                          colors: song.colors,
                          size: 52,
                          borderRadius: 0,
                          mediaStoreId: song.mediaStoreId,
                        ),
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _genreSelection() {
    final genres = {..._defaultGenres, ..._customGenres}.toList()..sort();
    return LayoutBuilder(
      key: const ValueKey('quick-fill-genres'),
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 520
            ? 3
            : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 116),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 80,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: genres.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _AddGenreCard(onTap: _addCustomGenre);
            }
            final genre = genres[index - 1];
            return _GenreChoiceCard(
              genre: genre,
              icon: _customIcons[genre] ?? genreIconFor(genre),
              selected: genre == _selectedGenre,
              onTap: () => setState(() {
                _selectedGenre = genre;
                _error = null;
              }),
            );
          },
        );
      },
    );
  }

  Widget _dockedToolbar() {
    final colors = Theme.of(context).colorScheme;
    final canContinue = _step == 0
        ? _selectedSongIds.isNotEmpty
        : _selectedGenre != null;
    return Material(
      elevation: 6,
      shadowColor: colors.shadow.withValues(alpha: .2),
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(32),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: _error == null ? 64 : 88,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 5, 14, 0),
                child: Text(
                  error,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.error),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    if (_step == 0) ...[
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _SegmentAction(
                                label: 'Select all',
                                first: true,
                                onPressed: () => setState(
                                  () => _selectedSongIds.addAll(
                                    widget.songs.map((song) => song.id),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: _SegmentAction(
                                label: 'Clear',
                                first: false,
                                onPressed: () =>
                                    setState(() => _selectedSongIds.clear()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _selectedGenre == null
                              ? 'Select a genre'
                              : 'Genre: $_selectedGenre',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                    ],
                    FilledButton(
                      onPressed: canContinue && !_applying
                          ? (_step == 0 ? _next : _apply)
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: const StadiumBorder(),
                      ),
                      child: _applying
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_step == 0 ? 'Next' : 'Quick fill'),
                                const SizedBox(width: 8),
                                Icon(
                                  _step == 0
                                      ? Icons.arrow_forward_rounded
                                      : Icons.auto_fix_high_rounded,
                                  size: 20,
                                ),
                              ],
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

  void _toggleSong(String id) {
    setState(() {
      _selectedSongIds.contains(id)
          ? _selectedSongIds.remove(id)
          : _selectedSongIds.add(id);
    });
  }

  void _next() {
    setState(() {
      _step = 1;
      _error = null;
    });
  }

  Future<void> _apply() async {
    final genre = _selectedGenre;
    if (genre == null) return;
    setState(() {
      _applying = true;
      _error = null;
    });
    final selectedSongs = widget.songs
        .where((song) => _selectedSongIds.contains(song.id))
        .toList(growable: false);
    final error = await widget.onApply(selectedSongs, genre);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, genre);
    } else {
      setState(() {
        _applying = false;
        _error = error;
      });
    }
  }

  Future<void> _addCustomGenre() async {
    final result = await showDialog<(String, IconData)>(
      context: context,
      builder: (context) => const _NewGenreDialog(),
    );
    if (result == null || !mounted) return;
    setState(() {
      _customGenres.add(result.$1);
      _customIcons[result.$1] = result.$2;
      _selectedGenre = result.$1;
    });
    widget.onAddCustomGenre?.call(result);
  }
}

class _SegmentAction extends StatelessWidget {
  const _SegmentAction({
    required this.label,
    required this.first,
    required this.onPressed,
  });

  final String label;
  final bool first;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(first ? 50 : 4),
            right: Radius.circular(first ? 4 : 50),
          ),
        ),
      ),
      child: Text(label),
    );
  }
}

class _AddGenreCard extends StatelessWidget {
  const _AddGenreCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.primaryContainer.withValues(alpha: .5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: colors.primary),
            Text(
              'New genre',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreChoiceCard extends StatelessWidget {
  const _GenreChoiceCard({
    required this.genre,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String genre;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final contentColor = selected ? colors.onPrimary : colors.onSurface;
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? colors.primary : colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? colors.primaryContainer : colors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  genre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewGenreDialog extends StatefulWidget {
  const _NewGenreDialog();

  @override
  State<_NewGenreDialog> createState() => _NewGenreDialogState();
}

class _NewGenreDialogState extends State<_NewGenreDialog> {
  static const _icons = <IconData>[
    Icons.music_note_rounded,
    Icons.headphones_rounded,
    Icons.album_rounded,
    Icons.mic_external_on_rounded,
    Icons.speaker_rounded,
    Icons.favorite_rounded,
    Icons.piano_rounded,
    Icons.queue_music_rounded,
  ];

  final _name = TextEditingController();
  IconData _icon = _icons.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.category_rounded),
      title: const Text('Add custom genre'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Genre name'),
            ),
            const SizedBox(height: 18),
            Text('Select icon', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final icon in _icons)
                  IconButton.filledTonal(
                    isSelected: icon == _icon,
                    onPressed: () => setState(() => _icon = icon),
                    icon: Icon(icon),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (_name.text.trim(), _icon)),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
