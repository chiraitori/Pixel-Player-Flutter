import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/rounded_star_clipper.dart';
import '../../shared/widgets/artwork.dart';

enum _CreationMode { manual, smart }

enum _StorageFilter { offline, online }

class CreatePlaylistScreen extends StatefulWidget {
  const CreatePlaylistScreen({super.key});

  @override
  State<CreatePlaylistScreen> createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  static const _smartRules = <String, (String, String)>{
    'top_played': ('Top Played', 'Your most played tracks.'),
    'recently_played': (
      'Recently Played',
      'Songs you listened to most recently.',
    ),
    'forgotten_favorites': (
      'Forgotten Favorites',
      "Favorite tracks you haven't played in a while.",
    ),
    'new_gems': ('New Gems', 'Recently added tracks with low play counts.'),
  };
  static const _coverIcons = <String, IconData>{
    'MusicNote': Icons.music_note_rounded,
    'Headphones': Icons.headphones_rounded,
    'Album': Icons.album_rounded,
    'Mic': Icons.mic_external_on_rounded,
    'Speaker': Icons.speaker_rounded,
    'Favorite': Icons.favorite_rounded,
    'Piano': Icons.piano_rounded,
    'Queue': Icons.queue_music_rounded,
  };

  final _name = TextEditingController();
  final _search = TextEditingController();
  final _selected = <String>{};
  int _step = 0;
  int _coverTab = 0;
  _CreationMode _mode = _CreationMode.manual;
  _StorageFilter _storage = _StorageFilter.offline;
  String _smartRule = 'top_played';
  String? _customCoverPath;
  Color? _coverColor;
  String _coverIcon = _coverIcons.keys.first;
  String _coverShape = 'Circle';
  double _smoothRectCornerRadius = 20;
  double _smoothRectSmoothness = 60;
  int _starSides = 5;
  double _starCurve = .15;
  double _starRotation = 0;
  double _starScale = 1;

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manualSongStep = _step == 1 && _mode == _CreationMode.manual;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        leadingWidth: 58,
        leading: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: IconButton.filled(
            onPressed: () {
              if (manualSongStep) {
                setState(() => _step = 0);
              } else {
                Navigator.pop(context);
              }
            },
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerLowest,
            ),
            icon: Icon(
              manualSongStep ? Icons.arrow_back_rounded : Icons.close_rounded,
            ),
            tooltip: manualSongStep ? 'Back' : 'Close',
          ),
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            key: ValueKey((_step, _mode)),
            manualSongStep
                ? 'Add songs'
                : _mode == _CreationMode.smart
                ? 'New smart playlist'
                : 'New playlist',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      floatingActionButton: manualSongStep
          ? null
          : FloatingActionButton.extended(
              onPressed: _name.text.trim().isEmpty
                  ? null
                  : _mode == _CreationMode.manual
                  ? () => setState(() => _step = 1)
                  : _finish,
              backgroundColor: _name.text.trim().isEmpty
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.tertiaryContainer,
              foregroundColor: _name.text.trim().isEmpty
                  ? Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.38)
                  : Theme.of(context).colorScheme.onTertiaryContainer,
              icon: Icon(
                _mode == _CreationMode.manual
                    ? Icons.arrow_forward_rounded
                    : Icons.check_rounded,
              ),
              label: Text(
                _mode == _CreationMode.manual ? 'Next' : 'Create',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
      bottomNavigationBar: manualSongStep ? _songPickerBottomBar() : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: manualSongStep ? _songPicker() : _playlistForm(),
      ),
    );
  }

  Widget _playlistForm() {
    final colors = Theme.of(context).colorScheme;
    final coverColor = _coverColor ?? colors.primaryContainer;
    return ListView(
      key: const ValueKey('playlist-form'),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 112),
      children: [
        SizedBox(
          height: 240,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 180,
                child: _CoverPreview(
                  tab: _coverTab,
                  customCoverPath: _customCoverPath,
                  color: coverColor,
                  icon: _coverIcons[_coverIcon]!,
                  shape: _coverShape,
                  smoothRectCornerRadius: _smoothRectCornerRadius,
                  starSides: _starSides,
                  starCurve: _starCurve,
                  starRotation: _starRotation,
                  starScale: _starScale,
                  onPickImage: _pickCoverImage,
                ),
              ),
              if (_coverTab == 0) ...[
                const SizedBox(height: 12),
                Text(
                  'Automatic artwork collage',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        TextField(
          controller: _name,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Playlist name',
            hintText: 'Give your playlist a name',
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
        const SizedBox(height: 12),
        SegmentedButton<_CreationMode>(
          segments: const [
            ButtonSegment(
              value: _CreationMode.manual,
              icon: Icon(Icons.edit_rounded),
              label: Text('Manual'),
            ),
            ButtonSegment(
              value: _CreationMode.smart,
              icon: Icon(Icons.auto_awesome_rounded),
              label: Text('Smart'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (values) => setState(() => _mode = values.first),
        ),
        if (_mode == _CreationMode.smart) ...[
          const SizedBox(height: 14),
          Text(
            'Smart playlist rule',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _smartRules.entries)
                FilterChip(
                  selected: entry.key == _smartRule,
                  onSelected: (_) => setState(() => _smartRule = entry.key),
                  label: Text(entry.value.$1),
                  shape: const StadiumBorder(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _smartRules[_smartRule]!.$2,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 14),
        _ExpressiveButtonGroup(
          labels: const ['Default', 'Image', 'Icon'],
          selectedIndex: _coverTab,
          onSelected: (value) => setState(() => _coverTab = value),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: switch (_coverTab) {
            1 => Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _imageCoverControls(),
            ),
            2 => Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _iconCoverControls(),
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }

  Widget _imageCoverControls() {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: _pickCoverImage,
        leading: const Icon(Icons.add_photo_alternate_outlined),
        title: Text(_customCoverPath == null ? 'Pick image' : 'Change image'),
        subtitle: const Text('Choose and crop a playlist cover.'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Widget _iconCoverControls() {
    final colors = Theme.of(context).colorScheme;
    final coverColors = <Color>[
      colors.primary,
      colors.primaryContainer,
      colors.secondary,
      colors.secondaryContainer,
      colors.tertiary,
      colors.tertiaryContainer,
      colors.error,
      colors.errorContainer,
      colors.surfaceContainerHigh,
      colors.inverseSurface,
    ];
    _coverColor ??= colors.primaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Background color', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final color in coverColors)
              Semantics(
                selected: color == _coverColor,
                label: 'Cover color',
                button: true,
                child: InkWell(
                  onTap: () => setState(() => _coverColor = color),
                  borderRadius: BorderRadius.circular(
                    color == _coverColor ? 12 : 24,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 52,
                    height: 52,
                    padding: EdgeInsets.all(color == _coverColor ? 5 : 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(
                        color == _coverColor ? 12 : 24,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(
                          color == _coverColor ? 8 : 22,
                        ),
                        border: color == _coverColor
                            ? Border.all(color: colors.surface, width: 2)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Icon symbol', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in _coverIcons.entries)
              Semantics(
                label: entry.key,
                selected: entry.key == _coverIcon,
                button: true,
                child: InkWell(
                  onTap: () => setState(() => _coverIcon = entry.key),
                  borderRadius: BorderRadius.circular(
                    entry.key == _coverIcon ? 12 : 24,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: entry.key == _coverIcon
                          ? colors.primaryContainer
                          : colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(
                        entry.key == _coverIcon ? 12 : 24,
                      ),
                    ),
                    child: Icon(
                      entry.value,
                      color: entry.key == _coverIcon
                          ? colors.onPrimaryContainer
                          : colors.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Shape style', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final shape in const [
                'Circle',
                'SmoothRect',
                'RotatedPill',
                'Star',
              ])
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: Semantics(
                    label: shape,
                    selected: _coverShape == shape,
                    button: true,
                    child: InkWell(
                      onTap: () => setState(() => _coverShape = shape),
                      borderRadius: BorderRadius.circular(
                        _coverShape == shape ? 12 : 24,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 78,
                        height: 78,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _coverShape == shape
                              ? colors.primaryContainer
                              : colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            _coverShape == shape ? 12 : 24,
                          ),
                        ),
                        child: _ShapeSample(
                          shape: shape,
                          color: _coverShape == shape
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_coverShape == 'SmoothRect') ...[
          const SizedBox(height: 16),
          Text(
            'Shape parameters',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _ShapeParameterCard(
            title: 'Corner radius',
            value: _smoothRectCornerRadius,
            min: 0,
            max: 50,
            valueLabel: _smoothRectCornerRadius.round().toString(),
            onChanged: (value) =>
                setState(() => _smoothRectCornerRadius = value),
          ),
          const SizedBox(height: 8),
          _ShapeParameterCard(
            title: 'Smoothness',
            value: _smoothRectSmoothness,
            min: 0,
            max: 100,
            valueLabel: '${_smoothRectSmoothness.round()}%',
            onChanged: (value) => setState(() => _smoothRectSmoothness = value),
          ),
        ],
        if (_coverShape == 'Star') ...[
          const SizedBox(height: 16),
          Text(
            'Shape parameters',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _ShapeParameterCard(
            title: 'Sides',
            value: _starSides.toDouble(),
            min: 3,
            max: 20,
            divisions: 17,
            valueLabel: _starSides.toString(),
            onChanged: (value) => setState(() => _starSides = value.round()),
          ),
          const SizedBox(height: 8),
          _ShapeParameterCard(
            title: 'Curve',
            value: _starCurve,
            min: 0,
            max: .5,
            valueLabel: _starCurve.toStringAsFixed(2),
            onChanged: (value) => setState(() => _starCurve = value),
          ),
          const SizedBox(height: 8),
          _ShapeParameterCard(
            title: 'Rotation',
            value: _starRotation,
            min: 0,
            max: 360,
            valueLabel: '${_starRotation.round()}°',
            onChanged: (value) => setState(() => _starRotation = value),
          ),
          const SizedBox(height: 8),
          _ShapeParameterCard(
            title: 'Scale',
            value: _starScale,
            min: .5,
            max: 1.5,
            valueLabel: '${_starScale.toStringAsFixed(1)}×',
            onChanged: (value) => setState(() => _starScale = value),
          ),
        ],
      ],
    );
  }

  Widget _songPicker() {
    final controller = AppScope.of(context);
    final query = _search.text.trim().toLowerCase();
    final songs = controller.songs
        .where((song) {
          final matchesStorage = _storage == _StorageFilter.offline
              ? song.source == SongSource.local
              : song.source != SongSource.local;
          if (!matchesStorage) return false;
          return query.isEmpty ||
              song.title.toLowerCase().contains(query) ||
              song.artist.toLowerCase().contains(query) ||
              song.album.toLowerCase().contains(query);
        })
        .toList(growable: false);
    return Column(
      key: const ValueKey('playlist-song-picker'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search songs',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: [
              Text('${_selected.length} selected'),
              const Spacer(),
              TextButton(
                onPressed: () => setState(
                  () => _selected.addAll(songs.map((song) => song.id)),
                ),
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: () => setState(_selected.clear),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: songs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_off_rounded, size: 52),
                      SizedBox(height: 12),
                      Text('No songs in this source'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return CheckboxListTile(
                      value: _selected.contains(song.id),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _selected.add(song.id);
                        } else {
                          _selected.remove(song.id);
                        }
                      }),
                      secondary: Artwork(
                        colors: song.colors,
                        size: 52,
                        borderRadius: 10,
                        mediaStoreId: song.mediaStoreId,
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${song.artist} \u2022 ${song.album}',
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

  Widget _songPickerBottomBar() {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: SegmentedButton<_StorageFilter>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _StorageFilter.offline,
                      icon: Icon(Icons.phone_android_rounded),
                      label: Text('Offline'),
                    ),
                    ButtonSegment(
                      value: _StorageFilter.online,
                      icon: Icon(Icons.cloud_rounded),
                      label: Text('Online'),
                    ),
                  ],
                  selected: {_storage},
                  onSelectionChanged: (values) =>
                      setState(() => _storage = values.first),
                  style: ButtonStyle(
                    side: const WidgetStatePropertyAll(BorderSide.none),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox.square(
              dimension: 56,
              child: IconButton.filled(
                onPressed: _finish,
                style: IconButton.styleFrom(
                  backgroundColor: colors.tertiaryContainer,
                  foregroundColor: colors.onTertiaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 28),
                tooltip: 'Create',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choose playlist artwork',
      type: FileType.image,
    );
    final path = result?.files.single.path;
    if (path != null && mounted) setState(() => _customCoverPath = path);
  }

  void _finish() {
    final playlistName = _name.text.trim();
    if (playlistName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a playlist name')));
      return;
    }
    AppScope.of(context).createPlaylist(
      playlistName,
      _selected,
      coverPath: _coverTab == 1 ? _customCoverPath : null,
      coverColorValue: _coverTab == 2
          ? (_coverColor ?? Theme.of(context).colorScheme.primaryContainer)
                .toARGB32()
          : null,
      coverIconName: _coverTab == 2 ? _coverIcon : null,
      coverShape: _coverShape,
      coverShapeDetail1: switch (_coverShape) {
        'SmoothRect' => _smoothRectCornerRadius,
        'Star' => _starCurve,
        _ => null,
      },
      coverShapeDetail2: switch (_coverShape) {
        'SmoothRect' => _smoothRectSmoothness,
        'Star' => _starRotation,
        _ => null,
      },
      coverShapeDetail3: _coverShape == 'Star' ? _starScale : null,
      coverShapeDetail4: _coverShape == 'Star' ? _starSides.toDouble() : null,
      smartRule: _mode == _CreationMode.smart ? _smartRule : null,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$playlistName created')));
    Navigator.pop(context);
  }
}

class _ExpressiveButtonGroup extends StatelessWidget {
  const _ExpressiveButtonGroup({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          if (index > 0) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              selected: index == selectedIndex,
              button: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(
                    index == selectedIndex ? 999 : 10,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 48,
                    decoration: BoxDecoration(
                      color: index == selectedIndex
                          ? colors.primary
                          : colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(
                        index == selectedIndex ? 999 : 10,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          child: index == selectedIndex
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: colors.onPrimary,
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (index == selectedIndex) const SizedBox(width: 8),
                        Text(
                          labels[index],
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: index == selectedIndex
                                    ? colors.onPrimary
                                    : colors.onSurface,
                                fontWeight: index == selectedIndex
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShapeSample extends StatelessWidget {
  const _ShapeSample({required this.shape, required this.color});

  final String shape;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fill = ColoredBox(color: color);
    return switch (shape) {
      'Circle' => ClipOval(child: fill),
      'SmoothRect' => ClipRSuperellipse(
        borderRadius: BorderRadius.circular(12),
        child: fill,
      ),
      'RotatedPill' => Transform.rotate(
        angle: .785398,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: fill,
          ),
        ),
      ),
      'Star' => ClipPath(
        clipper: const RoundedStarClipper(sides: 5, curve: .15),
        child: fill,
      ),
      _ => fill,
    };
  }
}

class _ShapeParameterCard extends StatelessWidget {
  const _ShapeParameterCard({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
    this.divisions,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    valueLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.tab,
    required this.color,
    required this.icon,
    required this.shape,
    required this.smoothRectCornerRadius,
    required this.starSides,
    required this.starCurve,
    required this.starRotation,
    required this.starScale,
    required this.onPickImage,
    this.customCoverPath,
  });

  final int tab;
  final String? customCoverPath;
  final Color color;
  final IconData icon;
  final String shape;
  final double smoothRectCornerRadius;
  final int starSides;
  final double starCurve;
  final double starRotation;
  final double starScale;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final path = customCoverPath;
    if (tab == 1 && path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.file(File(path), fit: BoxFit.cover),
      );
    }
    if (tab == 1) {
      final colors = Theme.of(context).colorScheme;
      return Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(32),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPickImage,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_rounded,
                size: 56,
                color: colors.primary,
              ),
              const SizedBox(height: 12),
              Text('Pick image', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
      );
    }
    if (tab == 2) {
      final iconColor =
          ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? Colors.white
          : Colors.black;
      final iconWidget = Icon(icon, size: 80, color: iconColor);
      final colorBox = ColoredBox(
        color: color,
        child: Center(
          child: shape == 'RotatedPill'
              ? Transform.rotate(angle: -.785398, child: iconWidget)
              : iconWidget,
        ),
      );
      return switch (shape) {
        'Circle' => ClipOval(child: colorBox),
        'SmoothRect' => ClipRSuperellipse(
          borderRadius: BorderRadius.circular(smoothRectCornerRadius),
          child: colorBox,
        ),
        'RotatedPill' => Transform.rotate(
          angle: .785398,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: colorBox,
            ),
          ),
        ),
        'Star' => Transform.scale(
          scale: starScale,
          child: ClipPath(
            clipper: RoundedStarClipper(
              sides: starSides,
              curve: starCurve,
              rotation: starRotation,
            ),
            child: colorBox,
          ),
        ),
        _ => ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: colorBox,
        ),
      };
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Icon(
        Icons.grid_view_rounded,
        size: 80,
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: .5),
      ),
    );
  }
}
