import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/entities.dart' show GoogleCastDevice;
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/models/song.dart';
import '../../core/services/audio_meta_service.dart';
import '../../core/services/google_cast_service.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/artwork_color_extractor.dart';
import '../../core/theme/pixelplay_theme.dart';
import '../../shared/widgets/auto_scrolling_text.dart';
import '../../shared/widgets/song_tile.dart';
import 'album_carousel.dart';
import 'animated_playback_controls.dart';
import 'bottom_toggle_row.dart';
import 'full_player_top_bar.dart';
import 'lyrics_screen.dart';
import 'wavy_slider.dart';

class FullPlayer extends StatefulWidget {
  const FullPlayer({super.key});

  @override
  State<FullPlayer> createState() => _FullPlayerState();
}

class _FullPlayerState extends State<FullPlayer> {
  static final Map<int, Color> _artworkSeedCache = <int, Color>{};

  double _verticalDrag = 0;
  String? _paletteSongId;
  Color? _artworkSeed;

  void _syncArtworkSeed(Song song) {
    if (_paletteSongId == song.id) return;
    _paletteSongId = song.id;

    final mediaStoreId = song.mediaStoreId;
    _artworkSeed = mediaStoreId == null
        ? song.colors.first
        : _artworkSeedCache[mediaStoreId] ?? song.colors.first;
    if (mediaStoreId == null || _artworkSeedCache.containsKey(mediaStoreId)) {
      return;
    }

    final requestedSongId = song.id;
    unawaited(() async {
      try {
        final artwork = await OnAudioQuery().queryArtwork(
          mediaStoreId,
          ArtworkType.AUDIO,
          format: ArtworkFormat.JPEG,
          size: 256,
          quality: 90,
        );
        if (artwork == null || artwork.isEmpty) return;
        final seed = await extractPixelPlayerArtworkSeed(artwork);
        if (seed == null) return;
        _artworkSeedCache[mediaStoreId] = seed;
        if (!mounted || _paletteSongId != requestedSongId) return;
        setState(() => _artworkSeed = seed);
      } catch (_) {
        // Keep the deterministic fallback when artwork cannot be decoded.
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final song = controller.currentSong;
    if (song == null) return const SizedBox.shrink();
    _syncArtworkSeed(song);

    final brightness = Theme.of(context).brightness;
    final useAlbumColors = controller.boolSetting(
      'appearance_use_album_colors',
      true,
    );
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
    final playerColors = useAlbumColors
        ? ColorScheme.fromSeed(
            seedColor: _artworkSeed ?? song.colors.first,
            brightness: brightness,
            dynamicSchemeVariant: variant,
          )
        : Theme.of(context).colorScheme;
    final lightSystemIcons = brightness == Brightness.dark;
    final systemStyle = SystemUiOverlayStyle(
      statusBarColor: playerColors.surface,
      statusBarIconBrightness: lightSystemIcons
          ? Brightness.light
          : Brightness.dark,
      statusBarBrightness: lightSystemIcons
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarColor: playerColors.surface,
      systemNavigationBarIconBrightness: lightSystemIcons
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: playerColors.surface,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemStyle,
      child: Theme(
        data: PixelPlayTheme.fromColorScheme(playerColors),
        child: Material(
          color: playerColors.surface,
          child: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: (_) => _verticalDrag = 0,
              onVerticalDragUpdate: (details) {
                _verticalDrag += details.primaryDelta ?? 0;
              },
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (_verticalDrag > 5 || velocity > 150) {
                  controller.hideFullPlayer();
                } else if (_verticalDrag < -8 && velocity < -520) {
                  _showQueue(context);
                }
                _verticalDrag = 0;
              },
              onTap:
                  controller.boolSetting(
                    'behavior_tap_background_closes_player',
                    false,
                  )
                  ? controller.hideFullPlayer
                  : null,
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: GoogleCastService.instance,
                    builder: (context, _) => FullPlayerTopBar(
                      onCollapse: controller.hideFullPlayer,
                      onShowOutput: () => _showOutput(context, song),
                      onShowQueue: () => _showQueue(context),
                      isCastConnecting: GoogleCastService.instance.connecting,
                      remoteRouteName: GoogleCastService.instance.routeName,
                    ),
                  ),
                  Expanded(
                    child: OrientationBuilder(
                      builder: (context, orientation) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.fastOutSlowIn,
                          child: orientation == Orientation.landscape
                              ? _LandscapePlayerContent(
                                  key: const ValueKey('landscape-player'),
                                  song: song,
                                  onLyrics: () => _showLyrics(context, song),
                                  onQueue: () => _showQueue(context),
                                )
                              : _PortraitPlayerContent(
                                  key: const ValueKey('portrait-player'),
                                  song: song,
                                  onLyrics: () => _showLyrics(context, song),
                                  onQueue: () => _showQueue(context),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    final controller = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        maxChildSize: .94,
        minChildSize: .35,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Queue',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${controller.queue.length} songs',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _showQueueSaved(context),
                    icon: const Icon(Icons.save_rounded),
                    tooltip: 'Save queue',
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    onPressed: () => _showQueueMenu(context),
                    icon: const Icon(Icons.more_vert_rounded),
                    tooltip: 'Queue options',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                scrollController: scrollController,
                itemCount: controller.queue.length,
                onReorderItem: controller.reorderQueue,
                itemBuilder: (context, index) {
                  final item = controller.queue[index];
                  return SongTile(
                    key: ValueKey('${item.id}-$index'),
                    song: item,
                    queue: controller.queue,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQueueSaved(BuildContext context) async {
    final controller = AppScope.of(context);
    final name = TextEditingController(text: 'Current queue');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save queue'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              controller.createPlaylist(
                name.text,
                controller.queue.map((song) => song.id),
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Queue saved as a playlist')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
  }

  void _showQueueMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.shuffle_rounded),
              title: const Text('Shuffle queue'),
              onTap: () {
                AppScope.of(context).toggleShuffle();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bedtime_rounded),
              title: const Text('Sleep timer'),
              subtitle: Text(
                AppScope.of(context).sleepTimerLabel ?? 'Not active',
              ),
              onTap: () {
                Navigator.pop(context);
                _showSleepTimer(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_remove_rounded),
              title: const Text('Dismiss playlist'),
              onTap: () {
                Navigator.pop(context);
                AppScope.of(context).dismissPlaylist();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSleepTimer(BuildContext context) {
    final controller = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(
                  'Sleep timer',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in const [5, 10, 15, 30, 45, 60])
                    ActionChip(
                      label: Text('$minutes min'),
                      onPressed: () {
                        controller.setSleepTimer(Duration(minutes: minutes));
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.skip_next_rounded),
                title: const Text('End of current track'),
                onTap: () {
                  controller.setSleepAtEndOfTrack();
                  Navigator.pop(context);
                },
              ),
              if (controller.sleepTimerLabel != null)
                ListTile(
                  leading: const Icon(Icons.timer_off_rounded),
                  title: const Text('Cancel timer'),
                  onTap: () {
                    controller.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLyrics(BuildContext context, Song song) {
    showLyricsFlow(context, song);
  }

  Future<void> _showOutput(BuildContext context, Song song) async {
    final cast = GoogleCastService.instance;
    await cast.startDiscovery();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 30),
        child: StreamBuilder<List<GoogleCastDevice>>(
          stream: cast.initialized ? cast.devicesStream : null,
          initialData: const [],
          builder: (context, snapshot) {
            final devices = snapshot.data ?? const [];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Audio output',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_android_rounded),
                  title: const Text('This device'),
                  subtitle: const Text('Built-in speaker'),
                  trailing: Icon(
                    cast.connected
                        ? Icons.radio_button_unchecked_rounded
                        : Icons.check_circle_rounded,
                  ),
                  onTap: cast.connected
                      ? () async {
                          final controller = AppScope.of(context);
                          final remotePosition = cast.remotePosition;
                          final wasPlaying = cast.remoteIsPlaying;
                          await cast.disconnect();
                          controller.resumePlaybackOnThisDevice(
                            remotePosition: remotePosition,
                            wasPlaying: wasPlaying,
                          );
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        }
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.bluetooth_audio_rounded),
                  title: const Text('Bluetooth device'),
                  subtitle: const Text('Choose a paired audio device'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    const MethodChannel(
                      'com.chiraitori.pixelplay/device_capabilities',
                    ).invokeMethod<void>('openAudioOutputSettings');
                  },
                ),
                if (cast.lastError != null)
                  ListTile(
                    leading: const Icon(Icons.error_outline_rounded),
                    title: Text(cast.lastError!),
                  )
                else if (devices.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.cast_rounded),
                    title: Text('Looking for Cast devices…'),
                    subtitle: Text('Use the same Wi-Fi network'),
                    trailing: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  for (final device in devices)
                    ListTile(
                      leading: const Icon(Icons.cast_rounded),
                      title: Text(device.friendlyName),
                      subtitle: Text(device.modelName ?? 'Google Cast'),
                      trailing: cast.routeName == device.friendlyName
                          ? const Icon(Icons.check_circle_rounded)
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final controller = AppScope.of(context);
                        if (controller.isPlaying) {
                          controller.togglePlayPause();
                        }
                        try {
                          await cast.castSong(
                            device,
                            song,
                            position: controller.position,
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(cast.lastError ?? '$error')),
                          );
                        }
                      },
                    ),
              ],
            );
          },
        ),
      ),
    );
    await cast.stopDiscovery();
  }
}

class _PortraitPlayerContent extends StatelessWidget {
  const _PortraitPlayerContent({
    required this.song,
    required this.onLyrics,
    required this.onQueue,
    super.key,
  });

  final Song song;
  final VoidCallback onLyrics;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = (constraints.maxWidth - 48).clamp(0.0, 600.0);
        final heightForArtwork = constraints.hasBoundedHeight
            ? (constraints.maxHeight - 352).clamp(120.0, contentWidth)
            : contentWidth;
        final artworkSize = heightForArtwork.clamp(120.0, contentWidth);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              SizedBox(
                width: artworkSize,
                height: artworkSize,
                child: AlbumCarousel(
                  currentSong: song,
                  queue: controller.queue,
                  isPlaying: controller.isPlaying,
                  viewportFraction: 1,
                  onSongSelected: (selected) => controller.playSong(
                    selected,
                    fromQueue: controller.queue,
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
                  ),
                  const SizedBox(height: 4),
                  _PlayerProgress(song: song),
                ],
              ),
              const _PlayerControlsBlock(),
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
    super.key,
  });

  final Song song;
  final VoidCallback onLyrics;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
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
                viewportFraction: 1,
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
    this.showQueue = false,
  });

  final Song song;
  final VoidCallback onLyrics;
  final VoidCallback onQueue;
  final bool showQueue;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final chipColor = colors.onPrimary.withValues(alpha: .8);
    return SizedBox(
      height: 68,
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
                      color: colors.onSurface,
                      fontFamily: 'GoogleSansFlex',
                      fontWeight: FontWeight.bold,
                    ),
                    gradientEdgeColor: colors.surface,
                    canScroll: controller.isPlaying,
                  ),
                  const SizedBox(height: 2),
                  AutoScrollingText(
                    text: song.artist,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                    gradientEdgeColor: colors.surface,
                    canScroll: controller.isPlaying,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (showQueue) ...[
            _MetadataChip(
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
      height: 44,
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
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: WavySlider(
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
                    activeColor: colors.primary,
                    inactiveColor: colors.primary.withValues(alpha: .25),
                    thumbColor: colors.primary,
                    isPlaying: controller.isPlaying,
                    strokeWidth: 4.5,
                    thumbRadius: 7.5,
                    trackEdgePadding: 4,
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
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _duration(widget.song.duration),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
                          color: colors.onSurface.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          audioMetaLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
    final mimeType = song.mimeType;

    final formatLabel = mimeType != null && mimeType.isNotEmpty
        ? AudioMetaService.mimeTypeToFormat(mimeType)
        : null;
    final validFormat = (formatLabel != null && formatLabel != '-')
        ? formatLabel.toUpperCase()
        : null;

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
            ),
          ),

          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: BottomToggleRow(
              shuffleEnabled: controller.shuffleEnabled,
              repeatMode: controller.repeatMode,
              favorite: controller.isFavorite(song),
              onShuffle: controller.toggleShuffle,
              onRepeat: controller.cycleRepeatMode,
              onFavorite: controller.toggleFavorite,
            ),
          ),
        ],
      ),
    );
  }
}
