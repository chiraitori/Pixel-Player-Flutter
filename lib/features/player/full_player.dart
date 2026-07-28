import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/models/song.dart';
import '../../core/services/audio_meta_service.dart';
import '../../core/services/google_cast_service.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/pixelplay_theme.dart';
import '../../shared/widgets/auto_scrolling_text.dart';
import '../details/album_detail_screen.dart';
import '../details/artist_detail_screen.dart';
import 'album_carousel.dart';
import 'animated_playback_controls.dart';
import 'bottom_toggle_row.dart';
import 'cast_bottom_sheet.dart';
import 'full_player_top_bar.dart';
import 'lyrics_screen.dart';
import 'player_artist_picker_sheet.dart';
import 'player_color_scheme_transition.dart';
import 'queue_bottom_sheet.dart';
import 'wavy_slider.dart';

class FullPlayer extends StatefulWidget {
  const FullPlayer({super.key});

  @override
  State<FullPlayer> createState() => _FullPlayerState();
}

class _FullPlayerState extends State<FullPlayer>
    with SingleTickerProviderStateMixin {
  static const _deviceCapabilitiesChannel = MethodChannel(
    'com.chiraitori.pixelplay/device_capabilities',
  );

  double _verticalDrag = 0;
  late final AnimationController _dragMotion;
  AppController? _controller;
  bool _isBluetoothActive = false;
  String? _bluetoothName;
  bool _isPlayerSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _dragMotion = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        final controller = _controller;
        if (controller == null) return;
        controller.fullPlayerDragOffset.value = _dragMotion.value.clamp(
          0,
          double.infinity,
        );
      });
    unawaited(_loadAudioRoute());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AppScope.of(context);
  }

  @override
  void dispose() {
    _controller?.fullPlayerDragOffset.value = 0;
    _dragMotion.dispose();
    super.dispose();
  }

  Future<void> _loadAudioRoute() async {
    try {
      final capabilities = await _deviceCapabilitiesChannel
          .invokeMapMethod<String, dynamic>('getCapabilities');
      if (!mounted || capabilities == null) return;
      setState(() {
        _isBluetoothActive = capabilities['bluetoothActive'] == true;
        _bluetoothName = capabilities['bluetoothName']?.toString();
      });
    } on MissingPluginException {
      // Widget tests and non-Android platforms keep the local-speaker state.
    } on PlatformException {
      // Keep the local-speaker state if Android cannot inspect the route.
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final song = controller.currentSong;
    if (song == null) return const SizedBox.shrink();

    final brightness = Theme.of(context).brightness;
    final useAlbumColors =
        controller.stringSetting(
          'appearance_player_palette',
          controller.boolSetting('appearance_use_album_colors', true)
              ? 'Album Art'
              : 'System Dynamic',
        ) ==
        'Album Art';
    final variant = switch (controller.stringSetting(
      'appearance_palette_style',
      'Tonal spot',
    )) {
      'Tonal spot' => DynamicSchemeVariant.tonalSpot,
      'Vibrant' => DynamicSchemeVariant.vibrant,
      'Expressive' => DynamicSchemeVariant.expressive,
      'Fidelity' => DynamicSchemeVariant.fidelity,
      'Monochrome' => DynamicSchemeVariant.monochrome,
      _ => DynamicSchemeVariant.tonalSpot,
    };
    final targetPlayerColors = useAlbumColors
        ? ColorScheme.fromSeed(
            seedColor: controller.playerPaletteSeedFor(song),
            brightness: brightness,
            dynamicSchemeVariant: variant,
          )
        : Theme.of(context).colorScheme;

    return PlayerColorSchemeTransition(
      target: targetPlayerColors,
      builder: (context, playerColors, _) {
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final playerBackground = playerColors.primaryContainer;
        final lightSystemIcons =
            ThemeData.estimateBrightnessForColor(playerBackground) ==
            Brightness.dark;
        final systemStyle = SystemUiOverlayStyle(
          statusBarColor: playerBackground,
          statusBarIconBrightness: lightSystemIcons
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: lightSystemIcons
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarColor: playerBackground,
          systemNavigationBarIconBrightness: lightSystemIcons
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarDividerColor: playerBackground,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemStyle,
          child: Theme(
            data: PixelPlayTheme.fromColorScheme(playerColors),
            child: ColoredBox(
              key: const ValueKey('full-player-depth-background'),
              color: playerBackground,
              child: AnimatedScale(
                key: const ValueKey('full-player-sheet-depth'),
                scale: _isPlayerSheetOpen ? .972 : 1,
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.fastOutSlowIn,
                // Keep the depth animation itself active, but mute continuous
                // player tickers while Queue/Connect device covers the player.
                child: TickerMode(
                  enabled: !_isPlayerSheetOpen,
                  child: Material(
                    color: playerBackground,
                    // Compose draws the player edge-to-edge horizontally and
                    // only consumes the system bars vertically. Flutter's
                    // default SafeArea adds this device's curved-display inset
                    // on both sides, which made the artwork too narrow.
                    child: SafeArea(
                      left: false,
                      right: false,
                      child: GestureDetector(
                        key: const ValueKey('full-player-drag-surface'),
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragStart: (_) {
                          _dragMotion.stop();
                          _verticalDrag = 0;
                          controller.fullPlayerDragOffset.value = 0;
                        },
                        onVerticalDragUpdate: (details) {
                          _verticalDrag += details.primaryDelta ?? 0;
                          controller.fullPlayerDragOffset.value = _verticalDrag
                              .clamp(0, MediaQuery.sizeOf(context).height);
                        },
                        onVerticalDragEnd: (details) =>
                            _finishVerticalDrag(controller, details),
                        onVerticalDragCancel: () =>
                            _restoreVerticalDrag(controller),
                        onTap:
                            controller.boolSetting(
                              'behavior_tap_background_closes_player',
                              false,
                            )
                            ? controller.hideFullPlayer
                            : null,
                        child: OrientationBuilder(
                          builder: (context, orientation) {
                            final isLandscape =
                                orientation == Orientation.landscape;
                            return Column(
                              children: [
                                AnimatedSize(
                                  duration: reduceMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 350),
                                  curve: Curves.fastOutSlowIn,
                                  alignment: Alignment.topCenter,
                                  child: isLandscape
                                      ? const SizedBox(width: double.infinity)
                                      : AnimatedBuilder(
                                          animation: GoogleCastService.instance,
                                          builder: (context, _) =>
                                              FullPlayerTopBar(
                                                onCollapse:
                                                    controller.hideFullPlayer,
                                                onShowOutput: () =>
                                                    _showOutput(context, song),
                                                onShowQueue: () =>
                                                    _showQueue(context),
                                                isCastConnecting:
                                                    GoogleCastService
                                                        .instance
                                                        .connecting,
                                                remoteRouteName:
                                                    GoogleCastService
                                                        .instance
                                                        .routeName,
                                                isBluetoothActive:
                                                    _isBluetoothActive,
                                                bluetoothName: _bluetoothName,
                                                showCloudStream:
                                                    song.source ==
                                                        SongSource.telegram ||
                                                    song.source ==
                                                        SongSource.googleDrive,
                                              ),
                                        ),
                                ),
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: reduceMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 380),
                                    switchInCurve: Curves.fastOutSlowIn,
                                    child: isLandscape
                                        ? _LandscapePlayerContent(
                                            key: const ValueKey(
                                              'landscape-player',
                                            ),
                                            song: song,
                                            onLyrics: () =>
                                                _showLyrics(context, song),
                                            onQueue: () => _showQueue(context),
                                            onAlbum: (albumSong) =>
                                                _openAlbum(context, albumSong),
                                            onArtist: (artistSong) =>
                                                _openArtist(
                                                  context,
                                                  artistSong,
                                                ),
                                          )
                                        : _PortraitPlayerContent(
                                            key: const ValueKey(
                                              'portrait-player',
                                            ),
                                            song: song,
                                            onLyrics: () =>
                                                _showLyrics(context, song),
                                            onQueue: () => _showQueue(context),
                                            onAlbum: (albumSong) =>
                                                _openAlbum(context, albumSong),
                                            onArtist: (artistSong) =>
                                                _openArtist(
                                                  context,
                                                  artistSong,
                                                ),
                                          ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _finishVerticalDrag(
    AppController controller,
    DragEndDetails details,
  ) async {
    final velocity = details.primaryVelocity ?? 0;
    final shouldCollapse =
        _verticalDrag > 48 || (_verticalDrag > 16 && velocity > 700);
    final shouldOpenQueue = _verticalDrag < -8 && velocity < -520;

    if (shouldCollapse) {
      _dragMotion.value = controller.fullPlayerDragOffset.value;
      final screenHeight = MediaQuery.sizeOf(context).height;
      final remainingFraction =
          ((screenHeight - _dragMotion.value) / screenHeight).clamp(0, 1);
      await _dragMotion.animateTo(
        screenHeight,
        duration: Duration(
          milliseconds: (160 + 120 * remainingFraction).round(),
        ),
        curve: Curves.fastOutSlowIn,
      );
      if (!mounted) return;
      controller.hideFullPlayer();
      _dragMotion.value = 0;
      _verticalDrag = 0;
      return;
    }

    await _restoreVerticalDrag(controller, velocity: velocity);
    if (!mounted) return;
    if (shouldOpenQueue) _showQueue(context);
  }

  Future<void> _restoreVerticalDrag(
    AppController controller, {
    double velocity = 0,
  }) async {
    _dragMotion.value = controller.fullPlayerDragOffset.value;
    await _dragMotion.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 380, damping: 31.18),
        _dragMotion.value,
        0,
        velocity,
      ),
    );
    if (!mounted) return;
    controller.fullPlayerDragOffset.value = 0;
    _dragMotion.value = 0;
    _verticalDrag = 0;
  }

  void _showQueue(BuildContext context) {
    if (_isPlayerSheetOpen) return;
    unawaited(
      showPlayerQueueBottomSheet(
        context,
        onVisibilityChanged: _setPlayerSheetVisibility,
      ),
    );
  }

  void _showLyrics(BuildContext context, Song song) {
    showLyricsFlow(context, song);
  }

  void _openAlbum(BuildContext context, Song song) {
    final controller = AppScope.of(context);
    controller.hideFullPlayer();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AlbumDetailScreen(albumId: song.albumId?.toString() ?? song.album),
      ),
    );
  }

  void _openArtist(BuildContext context, Song song) {
    final controller = AppScope.of(context);
    final artistNames = controller.splitArtistNames(song.artist);
    final libraryArtists = controller.artists;
    final resolvedArtists = <Artist>[
      for (final name in artistNames)
        libraryArtists.firstWhere(
          (artist) => artist.name.toLowerCase() == name.toLowerCase(),
          orElse: () => Artist(
            id: '${song.artistId ?? 'artist'}:${name.toLowerCase()}',
            name: name,
            songs: [song],
          ),
        ),
    ];

    if (resolvedArtists.length > 1) {
      unawaited(
        showPlayerArtistPickerSheet(
          context: context,
          artists: resolvedArtists,
          onArtistSelected: (artist) =>
              _navigateToArtist(context, controller, artist.id),
        ),
      );
      return;
    }

    final artistId = resolvedArtists.isEmpty
        ? song.artistId?.toString() ?? song.artist
        : resolvedArtists.first.id;
    _navigateToArtist(context, controller, artistId);
  }

  void _navigateToArtist(
    BuildContext context,
    AppController controller,
    String artistId,
  ) {
    controller.hideFullPlayer();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArtistDetailScreen(artistId: artistId),
      ),
    );
  }

  Future<void> _showOutput(BuildContext context, Song song) async {
    if (_isPlayerSheetOpen) return;
    await showCastBottomSheet(
      context: context,
      song: song,
      onVisibilityChanged: _setPlayerSheetVisibility,
    );
  }

  void _setPlayerSheetVisibility(bool isVisible) {
    if (!mounted || _isPlayerSheetOpen == isVisible) return;
    setState(() => _isPlayerSheetOpen = isVisible);
  }
}

double _carouselFraction(AppController controller) {
  return switch (controller.stringSetting('carousel_style', 'No Peek')) {
    'One Peek' => .8,
    'Two Peek' => .6,
    _ => 1,
  };
}

class _PortraitPlayerContent extends StatelessWidget {
  const _PortraitPlayerContent({
    required this.song,
    required this.onLyrics,
    required this.onQueue,
    required this.onAlbum,
    required this.onArtist,
    super.key,
  });

  final Song song;
  final VoidCallback onLyrics;
  final VoidCallback onQueue;
  final ValueChanged<Song> onAlbum;
  final ValueChanged<Song> onArtist;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return LayoutBuilder(
      key: const ValueKey('player-portrait-content'),
      builder: (context, constraints) {
        final contentWidth = (constraints.maxWidth - 48).clamp(
          0.0,
          double.infinity,
        );
        final carouselFraction = _carouselFraction(controller);
        // The Kotlin FullPlayerAlbumCoverSection always derives artwork from
        // the available width; Column.SpaceAround allocates remaining height.
        final carouselWidth = contentWidth;
        final carouselHeight = carouselWidth * carouselFraction;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Kotlin's outer Box has an 8dp vertical inset while the
              // carousel itself remains width-sized. This gives the player its
              // 337dp artwork when playing, and lets the 0.95 scale shrink it
              // to the measured 320dp artwork when paused.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  key: const ValueKey('player-album-carousel'),
                  width: carouselWidth,
                  height: carouselHeight,
                  child: AlbumCarousel(
                    currentSong: song,
                    queue: controller.queue,
                    isPlaying: controller.isPlaying,
                    viewportFraction: carouselFraction,
                    onArtworkTap: onAlbum,
                    onSongSelected: (selected) => controller.playSong(
                      selected,
                      fromQueue: controller.queue,
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SongMetadata(
                    song: song,
                    onLyrics: onLyrics,
                    onQueue: onQueue,
                    onArtist: () => onArtist(song),
                  ),
                  const SizedBox(height: 4),
                  _PlayerProgress(song: song),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _PlayerControlsBlock(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LandscapePlayerContent extends StatelessWidget {
  const _LandscapePlayerContent({
    required this.song,
    required this.onLyrics,
    required this.onQueue,
    required this.onAlbum,
    required this.onArtist,
    super.key,
  });

  final Song song;
  final VoidCallback onLyrics;
  final VoidCallback onQueue;
  final ValueChanged<Song> onAlbum;
  final ValueChanged<Song> onArtist;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final carouselFraction = _carouselFraction(controller);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AlbumCarousel(
                currentSong: song,
                queue: controller.queue,
                isPlaying: controller.isPlaying,
                viewportFraction: carouselFraction,
                onArtworkTap: onAlbum,
                onSongSelected: (selected) =>
                    controller.playSong(selected, fromQueue: controller.queue),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.min,
              children: [
                _SongMetadata(
                  song: song,
                  onLyrics: onLyrics,
                  onQueue: onQueue,
                  onArtist: () => onArtist(song),
                  showQueue: true,
                ),
                _PlayerProgress(song: song),
                const _PlayerControlsBlock(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SongMetadata extends StatelessWidget {
  const _SongMetadata({
    required this.song,
    required this.onLyrics,
    required this.onQueue,
    required this.onArtist,
    this.showQueue = false,
  });

  final Song song;
  final VoidCallback onLyrics;
  final VoidCallback onQueue;
  final VoidCallback onArtist;
  final bool showQueue;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final chipColor = colors.onPrimary.withValues(alpha: .8);
    return SizedBox(
      key: const ValueKey('player-song-metadata'),
      height: 70,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AutoScrollingText(
                    text: song.title,
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                      color: colors.onPrimaryContainer,
                      fontFamily: 'GoogleSansFlex',
                      fontWeight: FontWeight.bold,
                      fontVariations: const [ui.FontVariation('ROND', 100)],
                    ),
                    gradientEdgeColor: colors.primaryContainer,
                    canScroll: controller.isPlaying,
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onArtist,
                    onLongPress: onArtist,
                    child: AutoScrollingText(
                      text: song.artist,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: colors.onPrimaryContainer.withValues(alpha: .7),
                        letterSpacing: 0,
                        fontVariations: const [ui.FontVariation('ROND', 100)],
                      ),
                      gradientEdgeColor: colors.primaryContainer,
                      canScroll: controller.isPlaying,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (showQueue) ...[
            _MetadataChip(
              key: const ValueKey('player-landscape-lyrics'),
              icon: Icons.lyrics_rounded,
              background: chipColor,
              foreground: colors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(50),
                bottomLeft: Radius.circular(50),
                topRight: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
              onTap: onLyrics,
            ),
            const SizedBox(width: 6),
            _MetadataChip(
              key: const ValueKey('player-landscape-queue'),
              icon: Icons.queue_music_rounded,
              background: chipColor,
              foreground: colors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomLeft: Radius.circular(6),
                topRight: Radius.circular(50),
                bottomRight: Radius.circular(50),
              ),
              onTap: onQueue,
            ),
          ] else
            SizedBox.square(
              dimension: 48,
              child: IconButton.filled(
                onPressed: onLyrics,
                style: IconButton.styleFrom(
                  backgroundColor: chipColor,
                  foregroundColor: colors.primary,
                ),
                icon: const Icon(Icons.lyrics_rounded),
                tooltip: 'Lyrics',
              ),
            ),
        ],
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.borderRadius,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 42,
      child: Material(
        color: background,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, color: foreground),
        ),
      ),
    );
  }
}

class _PlayerProgress extends StatefulWidget {
  const _PlayerProgress({required this.song});

  final Song song;

  @override
  State<_PlayerProgress> createState() => _PlayerProgressState();
}

class _PlayerProgressState extends State<_PlayerProgress> {
  double? _dragValue;
  int _lastHapticStep = -1;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final durationMs = widget.song.duration.inMilliseconds;
    final audioMetaLabel =
        controller.boolSetting('appearance_show_player_file_info', true)
        ? _audioMetaLabel(widget.song)
        : null;
    return ValueListenableBuilder<Duration>(
      valueListenable: controller.positionListenable,
      builder: (context, position, _) {
        final actual = durationMs == 0
            ? 0.0
            : position.inMilliseconds / durationMs;
        final value = (_dragValue ?? actual).clamp(0.0, 1.0);
        return SizedBox(
          key: const ValueKey('player-progress'),
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: WavySlider(
                    key: const ValueKey('player-progress-slider'),
                    value: value,
                    onChanged: (newValue) {
                      final step = (newValue * 20).floor();
                      if (step != _lastHapticStep) {
                        _lastHapticStep = step;
                        HapticFeedback.selectionClick();
                      }
                      setState(() => _dragValue = newValue);
                    },
                    onChangeEnd: (newValue) {
                      controller.seek(newValue);
                      setState(() => _dragValue = null);
                    },
                    activeColor: colors.onPrimaryContainer,
                    inactiveColor: colors.onPrimaryContainer.withValues(
                      alpha: .2,
                    ),
                    thumbColor: colors.onPrimaryContainer,
                    isPlaying: controller.isPlaying,
                    strokeWidth: 5,
                    thumbRadius: 8,
                    trackEdgePadding: 0,
                    wavelength: 40,
                    waveAmplitude: 4,
                  ),
                ),
              ),
              SizedBox(
                height: 22,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _duration(
                            Duration(
                              milliseconds: (value * durationMs).round(),
                            ),
                          ),
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontVariations: const [
                              ui.FontVariation('ROND', 100),
                            ],
                          ),
                        ),
                        Text(
                          _duration(widget.song.duration),
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontVariations: const [
                              ui.FontVariation('ROND', 100),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (audioMetaLabel != null)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 230),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.onPrimaryContainer.withValues(
                            alpha: .14,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          audioMetaLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onPrimaryContainer.withValues(
                              alpha: .96,
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontVariations: const [
                              ui.FontVariation('ROND', 100),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _duration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Formats the audio metadata string to match Kotlin's formatAudioMetaLabel:
  /// e.g. "48.0 kHz · 1831 kbps · FLAC"
  String? _audioMetaLabel(Song song) {
    final sampleRate = song.sampleRate;
    final bitrate = song.bitrate;
    final formatLabel = AudioMetaService.formatFor(
      filePath: song.path,
      contentUri: song.contentUri,
      mimeType: song.mimeType,
    );
    final validFormat = formatLabel == '-' ? null : formatLabel;

    final parts = <String>[];

    if (sampleRate != null && sampleRate > 0) {
      parts.add('${(sampleRate / 1000).toStringAsFixed(1)} kHz');
    }

    if (bitrate != null && bitrate > 0) {
      final kbps = '${bitrate ~/ 1000} kbps';
      if (validFormat != null) {
        parts.add('$kbps · $validFormat');
      } else {
        parts.add(kbps);
      }
    } else if (validFormat != null) {
      parts.add(validFormat);
    }

    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _PlayerControlsBlock extends StatelessWidget {
  const _PlayerControlsBlock();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final song = controller.currentSong;
    if (song == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 182,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: AnimatedPlaybackControls(
              key: const ValueKey('player-transport-controls'),
              isPlaying: controller.isPlaying,
              onPrevious: controller.skipPrevious,
              onPlayPause: controller.togglePlayPause,
              onNext: controller.skipNext,
              colorPrevious: colors.secondaryFixedDim,
              colorPlayPause: colors.tertiaryFixedDim,
              colorNext: colors.secondaryFixedDim,
              tintPrevious: colors.onSecondaryFixed,
              tintPlayPause: colors.onTertiaryFixed,
              tintNext: colors.onSecondaryFixed,
              height: 80,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 6),
              child: BottomToggleRow(
                key: const ValueKey('player-bottom-toggles'),
                shuffleEnabled: controller.shuffleEnabled,
                repeatMode: controller.repeatMode,
                favorite: controller.isFavorite(song),
                onShuffle: controller.toggleShuffle,
                onRepeat: controller.cycleRepeatMode,
                onFavorite: controller.toggleFavorite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
