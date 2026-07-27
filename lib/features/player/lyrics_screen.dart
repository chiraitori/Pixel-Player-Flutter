import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/data/ai/gemini_ai_client.dart';
import '../../core/data/ai/lyrics_ai_translator.dart';
import '../../core/data/lyrics_service.dart';
import '../../core/models/lyrics.dart';
import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/rounded_star_clipper.dart';
import '../../shared/widgets/artwork.dart';
import 'wavy_slider.dart';

Future<void> showLyricsFlow(BuildContext context, Song song) async {
  final controller = AppScope.of(context);
  final preference = LyricsSourcePreference.fromSetting(
    controller.stringSetting(
      'library_lyrics_source_priority',
      'Embedded first',
    ),
  );
  final colorScheme = Theme.of(context).colorScheme;
  final localLyrics = await LyricsService.instance.lyricsFor(
    song,
    preference: preference,
    includeRemote: false,
  );
  if (!context.mounted) return;
  if (localLyrics != null) {
    await _openLyricsScreen(context, song, localLyrics, colorScheme);
    return;
  }

  final picked = await showDialog<LyricsDocument>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .32),
    builder: (context) =>
        _LyricsPickupDialog(song: song, preference: preference),
  );
  if (picked == null || !context.mounted) return;
  await _openLyricsScreen(context, song, picked, colorScheme);
}

Future<void> _openLyricsScreen(
  BuildContext context,
  Song song,
  LyricsDocument lyrics,
  ColorScheme colorScheme,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(colorScheme: colorScheme),
        child: LyricsScreen(song: song, initialLyrics: lyrics),
      ),
    ),
  );
}

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({
    required this.song,
    required this.initialLyrics,
    super.key,
  });

  final Song song;
  final LyricsDocument initialLyrics;

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  final ScrollController _scrollController = ScrollController();
  late LyricsDocument _lyrics = widget.initialLyrics;
  bool _showSynced = true;
  bool _translating = false;
  bool _syncControlsVisible = false;
  bool _immersiveTemporarilyDisabled = false;
  bool _settingsLoaded = false;
  bool _wakelockApplied = false;
  int _syncOffsetMs = 0;
  int _lastActiveLine = -1;
  bool _controlsVisible = true;
  Timer? _immersiveTimer;

  @override
  void initState() {
    super.initState();
    _showSynced = _lyrics.hasSynced;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settingsLoaded) return;
    _settingsLoaded = true;
    final controller = AppScope.of(context);
    _syncOffsetMs =
        int.tryParse(
          controller.stringSetting('lyrics_sync_offset_${widget.song.id}', '0'),
        ) ??
        0;
    _applyWakelock(controller.boolSetting('lyrics_keep_screen_on', false));
    if (controller.boolSetting('immersive_lyrics', false)) {
      _resetImmersiveTimer();
    }
  }

  @override
  void dispose() {
    _immersiveTimer?.cancel();
    if (_wakelockApplied) {
      WakelockPlus.disable().catchError((_) {});
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final showTranslation = controller.boolSetting(
      'show_lyrics_translation',
      true,
    );
    final showRomanization = controller.boolSetting(
      'show_lyrics_romanization',
      true,
    );
    final alignment = controller.stringSetting('lyrics_alignment', 'left');
    final animatedLyrics = controller.boolSetting(
      'experimental_animated_lyrics',
      false,
    );
    final blurLyrics = controller.boolSetting('experimental_lyrics_blur', true);
    final immersive =
        controller.boolSetting('immersive_lyrics', false) &&
        !_immersiveTemporarilyDisabled;
    return Scaffold(
      backgroundColor: colors.primaryContainer,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: immersive ? _resetImmersiveTimer : null,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        ValueListenableBuilder<Duration>(
                          valueListenable: controller.positionListenable,
                          builder: (context, position, _) {
                            final adjustedPosition = Duration(
                              milliseconds:
                                  (position.inMilliseconds + _syncOffsetMs)
                                      .clamp(0, 1 << 62),
                            );
                            final active = _activeLine(adjustedPosition);
                            _keepActiveLineVisible(active);
                            return _showSynced && _lyrics.hasSynced
                                ? _SyncedLyricsList(
                                    controller: _scrollController,
                                    lines: _lyrics.synced,
                                    activeIndex: active,
                                    position: adjustedPosition,
                                    showTranslation: showTranslation,
                                    showRomanization: showRomanization,
                                    alignment: alignment,
                                    animatedLyrics: animatedLyrics,
                                    blurLyrics: blurLyrics,
                                    blurStrength:
                                        controller.doubleSetting(
                                          'experimental_lyrics_blur_strength',
                                          .25,
                                        ) *
                                        10,
                                    immersive: immersive,
                                    fromRemote: _lyrics.fromRemote,
                                    onLineTap: (line) {
                                      final seekMs =
                                          (line.time.inMilliseconds -
                                                  _syncOffsetMs)
                                              .clamp(0, 1 << 62);
                                      controller.seek(
                                        seekMs /
                                            mathMax(
                                              1,
                                              widget
                                                  .song
                                                  .duration
                                                  .inMilliseconds,
                                            ),
                                      );
                                    },
                                  )
                                : _StaticLyricsList(
                                    controller: _scrollController,
                                    lines: _lyrics.plain,
                                    alignment: alignment,
                                  );
                          },
                        ),
                        IgnorePointer(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              height: 130,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    colors.primaryContainer,
                                    colors.primaryContainer.withValues(
                                      alpha: 0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    colors.primaryContainer.withValues(
                                      alpha: 0,
                                    ),
                                    colors.primaryContainer,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          top: 4,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width - 36,
                            ),
                            child: _NowPlayingPill(
                              song: widget.song,
                              isPlaying: controller.isPlaying,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!immersive || _controlsVisible)
                    _PlaybackDock(
                      song: widget.song,
                      showSynced: _showSynced,
                      hasSynced: _lyrics.hasSynced,
                      syncControlsVisible:
                          _syncControlsVisible &&
                          _showSynced &&
                          _lyrics.hasSynced,
                      syncOffsetMs: _syncOffsetMs,
                      onSyncOffsetChanged: (offset) =>
                          _setSyncOffset(controller, offset),
                      onModeChanged: (value) {
                        if (_showSynced == value) return;
                        setState(() => _showSynced = value);
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(0);
                        }
                      },
                      onMore: () => _showLyricsOptions(controller),
                    ),
                ],
              ),
              if (_translating)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _activeLine(Duration position) {
    if (!_lyrics.hasSynced) return -1;
    var low = 0;
    var high = _lyrics.synced.length - 1;
    var answer = -1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      if (_lyrics.synced[middle].time <= position) {
        answer = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return answer;
  }

  void _keepActiveLineVisible(int active) {
    if (active < 0 || active == _lastActiveLine) return;
    _lastActiveLine = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final controller = AppScope.of(context);
      final showTranslation = controller.boolSetting(
        'show_lyrics_translation',
        true,
      );
      final showRomanization = controller.boolSetting(
        'show_lyrics_romanization',
        true,
      );
      final hasExtraText =
          (showTranslation &&
              _lyrics.synced.any((l) => l.translation?.isNotEmpty == true)) ||
          (showRomanization &&
              _lyrics.synced.any((l) => l.romanization?.isNotEmpty == true));
      final estimatedLineHeight = hasExtraText ? 68.0 : 54.0;
      final viewportHeight = _scrollController.position.viewportDimension;
      final target =
          (active * estimatedLineHeight - (viewportHeight / 2) + 120.0).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _showLyricsOptions(AppController controller) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _LyricsOptionsSheet(
        controller: controller,
        lyrics: _lyrics,
        showSynced: _showSynced,
        syncControlsVisible: _syncControlsVisible,
        immersiveTemporarilyDisabled: _immersiveTemporarilyDisabled,
        onKeepScreenOnChanged: (value) {
          controller.setBoolSetting('lyrics_keep_screen_on', value);
          _applyWakelock(value);
        },
        onImmersiveTemporarilyDisabledChanged: (value) {
          setState(() => _immersiveTemporarilyDisabled = value);
        },
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'save') {
      await _saveLyrics();
      return;
    }
    if (action == 'translate') {
      await _translateLyrics(controller);
      return;
    }
    if (action == 'sync') {
      setState(() => _syncControlsVisible = !_syncControlsVisible);
      return;
    }
    if (action == 'reset') {
      await LyricsService.instance.resetLyrics(widget.song);
      if (mounted) Navigator.pop(context);
      return;
    }
  }

  void _setSyncOffset(AppController controller, int offset) {
    setState(() => _syncOffsetMs = offset);
    controller.setStringSetting(
      'lyrics_sync_offset_${widget.song.id}',
      '$offset',
    );
  }

  void _applyWakelock(bool enabled) {
    if (_wakelockApplied == enabled) return;
    _wakelockApplied = enabled;
    WakelockPlus.toggle(enable: enabled).catchError((_) {});
  }

  void _resetImmersiveTimer() {
    _immersiveTimer?.cancel();
    if (!_controlsVisible && mounted) {
      setState(() => _controlsVisible = true);
    }
    _immersiveTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _immersiveTemporarilyDisabled) return;
      setState(() => _controlsVisible = false);
    });
  }

  Future<void> _saveLyrics() async {
    final safeTitle = widget.song.title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save lyrics',
        fileName: '${safeTitle.isEmpty ? 'lyrics' : safeTitle}.lrc',
        type: FileType.custom,
        allowedExtensions: const ['lrc'],
        bytes: Uint8List.fromList(utf8.encode(_lyrics.raw)),
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lyrics saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save lyrics: $error')));
    }
  }

  Future<void> _translateLyrics(AppController controller) async {
    final apiKey = controller.stringSetting('gemini_api_key', '').trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configure a Gemini API key in Settings → AI integration first.',
          ),
        ),
      );
      return;
    }
    setState(() => _translating = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Translating lyrics with Gemini…')),
    );
    try {
      final translated = await LyricsAiTranslator().translate(
        song: widget.song,
        lyrics: _lyrics,
        targetLanguage: Localizations.localeOf(context).toLanguageTag(),
        apiKey: apiKey,
        model: controller.stringSetting(
          'gemini_model',
          GeminiAiClient.defaultModel,
        ),
      );
      if (!mounted) return;
      setState(() => _lyrics = translated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lyrics translated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }
}

class _NowPlayingPill extends StatelessWidget {
  const _NowPlayingPill({required this.song, required this.isPlaying});

  final Song song;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLowest,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 66,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: _SpinningLyricsArtwork(song: song, isPlaying: isPlaying),
            ),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 18),
              child: Icon(
                Icons.graphic_eq_rounded,
                size: 18,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpinningLyricsArtwork extends StatefulWidget {
  const _SpinningLyricsArtwork({required this.song, required this.isPlaying});

  final Song song;
  final bool isPlaying;

  @override
  State<_SpinningLyricsArtwork> createState() => _SpinningLyricsArtworkState();
}

class _SpinningLyricsArtworkState extends State<_SpinningLyricsArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) _rotation.repeat();
  }

  @override
  void didUpdateWidget(covariant _SpinningLyricsArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying == oldWidget.isPlaying) return;
    if (widget.isPlaying) {
      _rotation.repeat();
    } else {
      _rotation.stop();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _rotation,
      child: Artwork(
        mediaStoreId: widget.song.mediaStoreId,
        colors: widget.song.colors,
        size: 54,
        borderRadius: 27,
      ),
    );
  }
}

class _SyncedLyricsList extends StatelessWidget {
  const _SyncedLyricsList({
    required this.controller,
    required this.lines,
    required this.activeIndex,
    required this.position,
    required this.showTranslation,
    required this.showRomanization,
    required this.alignment,
    required this.animatedLyrics,
    required this.blurLyrics,
    required this.blurStrength,
    required this.immersive,
    required this.fromRemote,
    required this.onLineTap,
  });

  final ScrollController controller;
  final List<SyncedLyricLine> lines;
  final int activeIndex;
  final Duration position;
  final bool showTranslation;
  final bool showRomanization;
  final String alignment;
  final bool animatedLyrics;
  final bool blurLyrics;
  final double blurStrength;
  final bool immersive;
  final bool fromRemote;
  final ValueChanged<SyncedLyricLine> onLineTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 130, 24, 100),
      itemCount: lines.length + (fromRemote ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == lines.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: TextButton(
                onPressed: () => launchUrl(Uri.parse('https://lrclib.net')),
                child: Text(
                  'Lyrics provided by LRCLIB',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
              ),
            ),
          );
        }
        final line = lines[index];
        final active = index == activeIndex;
        final distance = (index - activeIndex).abs();
        final textAlign = _lyricsTextAlign(alignment);
        final crossAxisAlignment = _lyricsCrossAxisAlignment(alignment);
        final scale = !animatedLyrics
            ? 1.0
            : active
            ? (immersive ? 1.02 : 1.1)
            : distance == 1
            ? .95
            : .85;
        final opacity = !animatedLyrics
            ? 1.0
            : active
            ? 1.0
            : distance == 1
            ? .62
            : .38;
        Widget content = Padding(
          padding: EdgeInsets.symmetric(
            vertical: animatedLyrics
                ? active
                      ? 32
                      : distance == 1
                      ? 16
                      : 8
                : 13,
          ),
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              _TimedLyricText(
                line: line,
                position: position,
                active: active,
                textAlign: textAlign,
              ),
              if (showRomanization && line.romanization?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    line.romanization!,
                    textAlign: textAlign,
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.onPrimaryContainer.withValues(
                        alpha: active ? .82 : .32,
                      ),
                    ),
                  ),
                ),
              if (showTranslation && line.translation?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    line.translation!,
                    textAlign: textAlign,
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.onPrimaryContainer.withValues(
                        alpha: active ? .72 : .28,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        content = AnimatedScale(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          scale: scale,
          alignment: _lyricsAlignment(alignment),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: opacity,
            child: content,
          ),
        );
        if (animatedLyrics && blurLyrics && distance > 0) {
          content = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: (distance * blurStrength).clamp(0, 10),
              sigmaY: (distance * blurStrength).clamp(0, 10),
            ),
            child: content,
          );
        }
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onLineTap(line),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            style:
                Theme.of(context).textTheme.headlineSmall?.copyWith(
                  height: 1.28,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? colors.onPrimaryContainer
                      : colors.onPrimaryContainer.withValues(alpha: .38),
                ) ??
                const TextStyle(),
            child: content,
          ),
        );
      },
    );
  }
}

class _TimedLyricText extends StatelessWidget {
  const _TimedLyricText({
    required this.line,
    required this.position,
    required this.active,
    required this.textAlign,
  });

  final SyncedLyricLine line;
  final Duration position;
  final bool active;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    if (line.words.isEmpty || !active) {
      return Text(line.text, textAlign: textAlign);
    }
    final inherited = DefaultTextStyle.of(context).style;
    final activeColor = Theme.of(context).colorScheme.onPrimaryContainer;
    return Text.rich(
      TextSpan(
        children: [
          for (final word in line.words)
            TextSpan(
              text: '${word.startsNewWord ? ' ' : ''}${word.text}',
              style: inherited.copyWith(
                color: word.time <= position
                    ? activeColor
                    : activeColor.withValues(alpha: .46),
              ),
            ),
        ],
      ),
      textAlign: textAlign,
    );
  }
}

class _LyricsSyncControls extends StatelessWidget {
  const _LyricsSyncControls({required this.offsetMs, required this.onChanged});

  final int offsetMs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          _SyncButton(label: '−.5', onTap: () => onChanged(offsetMs - 500)),
          const SizedBox(width: 6),
          _SyncButton(label: '−.1', onTap: () => onChanged(offsetMs - 100)),
          const SizedBox(width: 6),
          _SyncButton(
            flex: 13,
            label: offsetMs == 0
                ? '0s'
                : '${offsetMs >= 0 ? '+' : ''}${(offsetMs / 1000).toStringAsFixed(1)}s',
            selected: offsetMs != 0,
            onTap: offsetMs == 0 ? null : () => onChanged(0),
          ),
          const SizedBox(width: 6),
          _SyncButton(label: '+.1', onTap: () => onChanged(offsetMs + 100)),
          const SizedBox(width: 6),
          _SyncButton(label: '+.5', onTap: () => onChanged(offsetMs + 500)),
        ],
      ),
    );
  }
}

class _SyncButton extends StatelessWidget {
  const _SyncButton({
    required this.label,
    required this.onTap,
    this.flex = 10,
    this.selected = true,
  });

  final String label;
  final VoidCallback? onTap;
  final int flex;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      flex: flex,
      child: SizedBox.expand(
        child: FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: selected
                ? colors.secondaryFixedDim
                : colors.surfaceContainerLowest,
            foregroundColor: selected
                ? colors.onSecondaryFixed
                : colors.onSurfaceVariant,
            disabledBackgroundColor: colors.surfaceContainerLowest,
            disabledForegroundColor: colors.onSurfaceVariant,
            shape: const StadiumBorder(),
            textStyle: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          child: Text(label, maxLines: 1),
        ),
      ),
    );
  }
}

class _StaticLyricsList extends StatelessWidget {
  const _StaticLyricsList({
    required this.controller,
    required this.lines,
    required this.alignment,
  });

  final ScrollController controller;
  final List<String> lines;
  final String alignment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 130, 24, 24),
      children: [
        Text(
          lines.join('\n\n'),
          textAlign: _lyricsTextAlign(alignment),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            height: 1.48,
            color: colors.onPrimaryContainer.withValues(alpha: .72),
          ),
        ),
      ],
    );
  }
}

TextAlign _lyricsTextAlign(String alignment) => switch (alignment) {
  'center' => TextAlign.center,
  'right' => TextAlign.right,
  _ => TextAlign.left,
};

CrossAxisAlignment _lyricsCrossAxisAlignment(String alignment) =>
    switch (alignment) {
      'center' => CrossAxisAlignment.center,
      'right' => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };

Alignment _lyricsAlignment(String alignment) => switch (alignment) {
  'center' => Alignment.center,
  'right' => Alignment.centerRight,
  _ => Alignment.centerLeft,
};

class _PlaybackDock extends StatelessWidget {
  const _PlaybackDock({
    required this.song,
    required this.showSynced,
    required this.hasSynced,
    required this.syncControlsVisible,
    required this.syncOffsetMs,
    required this.onSyncOffsetChanged,
    required this.onModeChanged,
    required this.onMore,
  });

  final Song song;
  final bool showSynced;
  final bool hasSynced;
  final bool syncControlsVisible;
  final int syncOffsetMs;
  final ValueChanged<int> onSyncOffsetChanged;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (syncControlsVisible) ...[
            _LyricsSyncControls(
              offsetMs: syncOffsetMs,
              onChanged: onSyncOffsetChanged,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              AnimatedContainer(
                width: 78,
                height: 78,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: colors.tertiaryFixedDim,
                  borderRadius: BorderRadius.circular(
                    controller.isPlaying ? 18 : 50,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      controller.isPlaying ? 18 : 50,
                    ),
                    onTap: controller.togglePlayPause,
                    child: Icon(
                      controller.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: colors.onTertiaryFixed,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: controller.positionListenable,
                    builder: (context, position, _) => WavySlider(
                      value:
                          (position.inMilliseconds /
                                  mathMax(1, song.duration.inMilliseconds))
                              .clamp(0, 1),
                      onChanged: (_) {},
                      onChangeEnd: controller.seek,
                      activeColor: colors.primary,
                      inactiveColor: colors.primary.withValues(alpha: .2),
                      thumbColor: colors.primary,
                      isPlaying: controller.isPlaying,
                      strokeWidth: 5,
                      thumbRadius: 8,
                      wavelength: 30,
                      trackEdgePadding: 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox.square(
                dimension: 48,
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surfaceContainerLowest,
                    foregroundColor: colors.onSurface,
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _LyricsModeButton(
                        label: 'Synced',
                        active: showSynced,
                        enabled: hasSynced,
                        onTap: () => onModeChanged(true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LyricsModeButton(
                        label: 'Static',
                        active: !showSynced,
                        onTap: () => onModeChanged(false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 48,
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surfaceContainerLowest,
                    foregroundColor: colors.onSurface,
                  ),
                  onPressed: onMore,
                  icon: const Icon(Icons.more_vert_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LyricsModeButton extends StatelessWidget {
  const _LyricsModeButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: active
              ? colors.primary
              : colors.surfaceContainerLowest,
          foregroundColor: active ? colors.onPrimary : colors.onSurface,
          disabledBackgroundColor: colors.surfaceContainerLowest,
          disabledForegroundColor: colors.onSurface.withValues(alpha: .38),
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _LyricsOptionsSheet extends StatefulWidget {
  const _LyricsOptionsSheet({
    required this.controller,
    required this.lyrics,
    required this.showSynced,
    required this.syncControlsVisible,
    required this.immersiveTemporarilyDisabled,
    required this.onKeepScreenOnChanged,
    required this.onImmersiveTemporarilyDisabledChanged,
  });

  final AppController controller;
  final LyricsDocument lyrics;
  final bool showSynced;
  final bool syncControlsVisible;
  final bool immersiveTemporarilyDisabled;
  final ValueChanged<bool> onKeepScreenOnChanged;
  final ValueChanged<bool> onImmersiveTemporarilyDisabledChanged;

  @override
  State<_LyricsOptionsSheet> createState() => _LyricsOptionsSheetState();
}

class _LyricsOptionsSheetState extends State<_LyricsOptionsSheet> {
  late bool _immersiveTemporarilyDisabled = widget.immersiveTemporarilyDisabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final itemColor = colors.onSurface.withValues(alpha: .08);
    final hasRomanization = widget.lyrics.synced.any(
      (line) => line.romanization?.trim().isNotEmpty == true,
    );
    final hasTranslation = widget.lyrics.synced.any(
      (line) => line.translation?.trim().isNotEmpty == true,
    );
    final controls = <_LyricsControlSpec>[
      if (widget.showSynced && widget.lyrics.hasSynced)
        _LyricsControlSpec.action(
          icon: Icons.tune_rounded,
          title: widget.syncControlsVisible
              ? 'Hide sync controls'
              : 'Adjust synchronization',
          onTap: () => Navigator.pop(context, 'sync'),
        ),
      if (hasRomanization)
        _LyricsControlSpec.toggle(
          icon: Icons.abc_rounded,
          title: 'Show romanization',
          value: widget.controller.boolSetting(
            'show_lyrics_romanization',
            true,
          ),
          onChanged: (value) {
            widget.controller.setBoolSetting('show_lyrics_romanization', value);
            setState(() {});
          },
        ),
      if (hasTranslation)
        _LyricsControlSpec.toggle(
          icon: Icons.translate_rounded,
          title: 'Show translations',
          value: widget.controller.boolSetting('show_lyrics_translation', true),
          onChanged: (value) {
            widget.controller.setBoolSetting('show_lyrics_translation', value);
            setState(() {});
          },
        ),
      if (widget.showSynced &&
          widget.controller.boolSetting('immersive_lyrics', false))
        _LyricsControlSpec.toggle(
          icon: Icons.visibility_off_rounded,
          title: 'Disable immersive once',
          value: _immersiveTemporarilyDisabled,
          onChanged: (value) {
            _immersiveTemporarilyDisabled = value;
            widget.onImmersiveTemporarilyDisabledChanged(value);
            setState(() {});
          },
        ),
      _LyricsControlSpec.toggle(
        icon: Icons.brightness_high_rounded,
        title: 'Keep screen on',
        value: widget.controller.boolSetting('lyrics_keep_screen_on', false),
        onChanged: (value) {
          widget.onKeepScreenOnChanged(value);
          setState(() {});
        },
      ),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LyricsSheetHeading(label: 'Lyrics', color: colors.primary),
            _LyricsOptionTile(
              icon: Icons.save_outlined,
              title: 'Save lyrics',
              backgroundColor: itemColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
                bottom: Radius.circular(8),
              ),
              onTap: () => Navigator.pop(context, 'save'),
            ),
            const SizedBox(height: 2),
            _LyricsOptionTile(
              icon: Icons.translate_rounded,
              title: 'Translate lyrics with AI',
              backgroundColor: itemColor,
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.pop(context, 'translate'),
            ),
            const SizedBox(height: 2),
            _LyricsOptionTile(
              icon: Icons.restart_alt_rounded,
              title: 'Reset imported lyrics',
              backgroundColor: itemColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
                bottom: Radius.circular(18),
              ),
              onTap: _confirmReset,
            ),
            const SizedBox(height: 10),
            _LyricsSheetHeading(label: 'Appearance', color: colors.primary),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: itemColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alignment',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _alignmentButton('left', Icons.format_align_left_rounded),
                      const SizedBox(width: 8),
                      _alignmentButton(
                        'center',
                        Icons.format_align_center_rounded,
                      ),
                      const SizedBox(width: 8),
                      _alignmentButton(
                        'right',
                        Icons.format_align_right_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _LyricsSheetHeading(label: 'Controls', color: colors.primary),
            for (var index = 0; index < controls.length; index++) ...[
              if (index > 0) const SizedBox(height: 2),
              _LyricsOptionTile(
                icon: controls[index].icon,
                title: controls[index].title,
                backgroundColor: itemColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(index == 0 ? 18 : 8),
                  bottom: Radius.circular(
                    index == controls.length - 1 ? 24 : 8,
                  ),
                ),
                trailing: controls[index].value == null
                    ? null
                    : Switch(
                        value: controls[index].value!,
                        onChanged: controls[index].onChanged,
                      ),
                onTap:
                    controls[index].onTap ??
                    () => controls[index].onChanged?.call(
                      !(controls[index].value ?? false),
                    ),
              ),
            ],
            const SizedBox(height: 18),
            _LyricsPlaybackToggles(controller: widget.controller),
          ],
        ),
      ),
    );
  }

  Widget _alignmentButton(String value, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    final selected =
        widget.controller.stringSetting('lyrics_alignment', 'left') == value;
    return Expanded(
      child: SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: () {
            widget.controller.setStringSetting('lyrics_alignment', value);
            setState(() {});
          },
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: selected
                ? colors.primary
                : colors.surfaceContainerLow,
            foregroundColor: selected
                ? colors.onPrimary
                : colors.onSurface.withValues(alpha: .78),
            shape: const StadiumBorder(),
          ),
          child: Icon(icon),
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset lyrics?'),
        content: const Text(
          'Are you sure you want to reset the lyrics for this song?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Reset',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, 'reset');
    }
  }
}

class _LyricsSheetHeading extends StatelessWidget {
  const _LyricsSheetHeading({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
      ),
    );
  }
}

class _LyricsOptionTile extends StatelessWidget {
  const _LyricsOptionTile({
    required this.icon,
    required this.title,
    required this.backgroundColor,
    required this.borderRadius,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _LyricsControlSpec {
  const _LyricsControlSpec.action({
    required this.icon,
    required this.title,
    required this.onTap,
  }) : value = null,
       onChanged = null;

  const _LyricsControlSpec.toggle({
    required this.icon,
    required this.title,
    required bool this.value,
    required ValueChanged<bool> this.onChanged,
  }) : onTap = null;

  final IconData icon;
  final String title;
  final bool? value;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onChanged;
}

class _LyricsPlaybackToggles extends StatefulWidget {
  const _LyricsPlaybackToggles({required this.controller});

  final AppController controller;

  @override
  State<_LyricsPlaybackToggles> createState() => _LyricsPlaybackTogglesState();
}

class _LyricsPlaybackTogglesState extends State<_LyricsPlaybackToggles> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final song = widget.controller.currentSong;
    return Container(
      height: 74,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(8),
      decoration: ShapeDecoration(
        color: colors.surfaceContainer,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(60)),
        ),
      ),
      child: Row(
        children: [
          _toggle(
            active: widget.controller.shuffleEnabled,
            activeColor: colors.primary,
            activeContentColor: colors.onPrimary,
            icon: Icons.shuffle_rounded,
            onTap: () {
              widget.controller.toggleShuffle();
              setState(() {});
            },
          ),
          const SizedBox(width: 8),
          _toggle(
            active: widget.controller.repeatMode != 0,
            activeColor: colors.secondary,
            activeContentColor: colors.onSecondary,
            icon: widget.controller.repeatMode == 1
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            onTap: () {
              widget.controller.cycleRepeatMode();
              setState(() {});
            },
          ),
          const SizedBox(width: 8),
          _toggle(
            active: song != null && widget.controller.isFavorite(song),
            activeColor: colors.tertiary,
            activeContentColor: colors.onTertiary,
            icon: song != null && widget.controller.isFavorite(song)
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            onTap: () {
              widget.controller.toggleFavorite();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _toggle({
    required bool active,
    required Color activeColor,
    required Color activeContentColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: active ? activeColor : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(active ? 60 : 20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Icon(
              icon,
              color: active ? activeContentColor : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricsPickupDialog extends StatefulWidget {
  const _LyricsPickupDialog({required this.song, required this.preference});

  final Song song;
  final LyricsSourcePreference preference;

  @override
  State<_LyricsPickupDialog> createState() => _LyricsPickupDialogState();
}

class _LyricsPickupDialogState extends State<_LyricsPickupDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  bool _forcePicker = false;
  bool _loading = false;
  bool _notFound = false;
  String? _error;
  List<LyricsSearchResult>? _results;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(
      text: _isUnknownArtist(widget.song.artist) ? '' : widget.song.artist,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      backgroundColor: colors.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 50),
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text('Searching for lyrics…'),
                    SizedBox(height: 50),
                  ],
                )
              : _error != null
              ? _errorContent()
              : _notFound
              ? _notFoundContent()
              : _results != null
              ? _resultPicker()
              : _idleContent(),
        ),
      ),
    );
  }

  Widget _idleContent() {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            key: const ValueKey('lyrics-rounded-star'),
            dimension: 72,
            child: ClipPath(
              clipper: const RoundedStarClipper(sides: 8, curve: .1),
              child: ColoredBox(
                color: colors.secondaryContainer,
                child: Icon(
                  Icons.music_note_rounded,
                  size: 40,
                  color: colors.onSecondaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.song.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            widget.song.artist,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            'Would you like to search for lyrics online?',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          Material(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
            child: SwitchListTile(
              value: _forcePicker,
              onChanged: (value) => setState(() => _forcePicker = value),
              title: const Text('Show lyric options'),
              subtitle: const Text(
                'Always open the picker instead of auto-applying the first match',
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Search'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _import,
              style: FilledButton.styleFrom(
                backgroundColor: colors.secondary,
                foregroundColor: colors.onSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Import'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultPicker() {
    final results = _results!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${results.length} lyrics matches',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 350),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: results.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == results.length) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(8, 16, 8, 8),
                  child: Text(
                    'Lyrics provided by LRCLIB',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final result = results[index];
              final colors = Theme.of(context).colorScheme;
              return Material(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: result.document.hasSynced
                        ? colors.primaryContainer
                        : colors.surfaceContainerHighest,
                    foregroundColor: result.document.hasSynced
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                    child: const Icon(Icons.music_note_rounded, size: 20),
                  ),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          result.trackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (result.document.hasSynced) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'SYNCED',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${result.artistName} • ${result.albumName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _accept(result),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
      _notFound = false;
      _results = null;
    });
    try {
      if (!_forcePicker) {
        final lyrics = await LyricsService.instance.lyricsFor(
          widget.song,
          preference: widget.preference,
          includeRemote: true,
        );
        if (!mounted) return;
        if (lyrics != null) {
          Navigator.pop(context, lyrics);
          return;
        }
      }
      final results = await LyricsService.instance.searchRemote(widget.song);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (results.isEmpty) {
          _notFound = true;
        } else {
          _results = results;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not search for lyrics.\n$error';
      });
    }
  }

  Widget _notFoundContent() {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 36,
              color: colors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Lyrics not found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Try editing the song title or artist to search again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _SearchField(label: 'Title', controller: _titleController),
          const SizedBox(height: 8),
          _SearchField(label: 'Artist', controller: _artistController),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _manualSearch,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Search'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorContent() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colors.errorContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: colors.onErrorContainer,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Error',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: colors.error),
        ),
        const SizedBox(height: 8),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            child: const Text('OK'),
          ),
        ),
      ],
    );
  }

  Future<void> _manualSearch() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _notFound = false;
      _results = null;
    });
    try {
      final results = await LyricsService.instance.searchRemoteByQuery(
        widget.song,
        title: title,
        artist: _artistController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (results.isEmpty) {
          _notFound = true;
        } else {
          _results = results;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not search for lyrics.\n$error';
      });
    }
  }

  Future<void> _accept(LyricsSearchResult result) async {
    await LyricsService.instance.saveLyrics(widget.song, result.document);
    if (mounted) Navigator.pop(context, result.document);
  }

  Future<void> _import() async {
    final imported = await _pickLyricsFile(widget.song, context: context);
    if (imported != null && mounted) Navigator.pop(context, imported);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        TextField(
          controller: controller,
          maxLines: 1,
          decoration: InputDecoration(hintText: label),
        ),
      ],
    );
  }
}

bool _isUnknownArtist(String artist) {
  final normalized = artist.trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == '<unknown>' ||
      normalized == 'unknown' ||
      normalized == 'unknown artist';
}

Future<LyricsDocument?> _pickLyricsFile(
  Song song, {
  BuildContext? context,
}) async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['lrc', 'ttml'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    return await LyricsService.instance.importLyricsFile(song, File(path));
  } on FormatException catch (error) {
    if (context?.mounted == true) {
      ScaffoldMessenger.of(
        context!,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
    return null;
  }
}

int mathMax(int first, int second) => first > second ? first : second;
