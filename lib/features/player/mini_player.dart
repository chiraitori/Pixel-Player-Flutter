import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/models/song.dart';
import '../../core/services/google_cast_service.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/player_palette_cache.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/auto_scrolling_text.dart';
import '../shell/player_internal_navigation_bar.dart';

const double miniPlayerHeight = 64;
const double miniPlayerBottomSpacer = 8;

enum _DismissDragPhase { idle, tension, freeDrag }

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key, this.isNavBarHidden});

  final bool? isNavBarHidden;

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  static const _snapThreshold = 100.0;
  static const _maxTensionOffset = 30.0;

  late final AnimationController _horizontalOffset;
  _DismissDragPhase _phase = _DismissDragPhase.idle;
  double _accumulatedDragX = 0;
  String? _paletteSongId;
  Color? _artworkSeed;

  @override
  void initState() {
    super.initState();
    _horizontalOffset = AnimationController.unbounded(vsync: this);
    GoogleCastService.instance.addListener(_onCastStateChanged);
  }

  @override
  void dispose() {
    GoogleCastService.instance.removeListener(_onCastStateChanged);
    _horizontalOffset.dispose();
    super.dispose();
  }

  void _onCastStateChanged() {
    if (mounted) setState(() {});
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _horizontalOffset.stop();
    _phase = _DismissDragPhase.tension;
    _accumulatedDragX = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _accumulatedDragX += details.primaryDelta ?? 0;

    if (_phase == _DismissDragPhase.tension) {
      if (_accumulatedDragX.abs() < _snapThreshold) {
        final fraction = (_accumulatedDragX.abs() / _snapThreshold).clamp(
          0.0,
          1.0,
        );
        _horizontalOffset.value =
            _maxTensionOffset * fraction * _accumulatedDragX.sign;
        return;
      }
      _phase = _DismissDragPhase.freeDrag;
      if (AppScope.of(context).boolSetting('behavior_haptic_feedback', true)) {
        HapticFeedback.heavyImpact();
      }
    }

    if (_phase == _DismissDragPhase.freeDrag) {
      _horizontalOffset.value = _accumulatedDragX;
    }
  }

  Future<void> _onHorizontalDragEnd(DragEndDetails details) async {
    _phase = _DismissDragPhase.idle;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dismissThreshold = screenWidth * .4;

    if (_accumulatedDragX.abs() > dismissThreshold) {
      final target = _accumulatedDragX.isNegative ? -screenWidth : screenWidth;
      await _horizontalOffset.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.fastOutSlowIn,
      );
      if (!mounted) return;
      AppScope.of(context).dismissPlaylist();
      _horizontalOffset.value = 0;
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    await _horizontalOffset.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 500, damping: 24),
        _horizontalOffset.value,
        0,
        velocity,
      ),
    );
  }

  void _syncArtworkSeed(Song song) {
    if (_paletteSongId == song.id) return;
    _paletteSongId = song.id;
    _artworkSeed = song.colors.isEmpty ? Colors.deepPurple : song.colors.first;

    final requestedSongId = song.id;
    unawaited(() async {
      final seed = await PlayerPaletteCache.seedFor(song);
      if (!mounted || _paletteSongId != requestedSongId) return;
      setState(() => _artworkSeed = seed);
    }());
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final song = controller.currentSong;
    if (song == null) return const SizedBox.shrink();
    _syncArtworkSeed(song);
    final castConnecting = GoogleCastService.instance.connecting;

    final appColors = Theme.of(context).colorScheme;
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
    final targetColors = useAlbumColors
        ? ColorScheme.fromSeed(
            seedColor: _artworkSeed ?? Colors.deepPurple,
            brightness: Theme.of(context).brightness,
            dynamicSchemeVariant: variant,
          )
        : appColors;
    final swipeToDismiss = controller.boolSetting(
      'behavior_swipe_to_dismiss',
      true,
    );
    final systemInset = sanitizeNavigationBarBottomInset(
      MediaQuery.viewPaddingOf(context).bottom,
    );
    final horizontalPadding =
        controller.navBarStyle == PixelNavBarStyle.fullWidth
        ? 14.0
        : systemInset > 30
        ? 14.0
        : systemInset;
    final isNavBarHidden =
        widget.isNavBarHidden ?? (ModalRoute.of(context)?.canPop ?? false);
    final topRadius = controller.navBarStyle == PixelNavBarStyle.fullWidth
        ? 32.0
        : controller.navBarCornerRadius;
    final bottomRadius = isNavBarHidden
        ? (controller.navBarStyle == PixelNavBarStyle.fullWidth
            ? 32.0
            : controller.navBarCornerRadius)
        : (controller.navBarStyle == PixelNavBarStyle.fullWidth ? 32.0 : 10.0);
    final miniPlayerBorderRadius = BorderRadius.vertical(
      top: Radius.circular(topRadius),
      bottom: Radius.circular(bottomRadius),
    );
    final useSmoothCorners = controller.boolSetting(
      'appearance_smooth_corners',
      true,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        0,
        horizontalPadding,
        miniPlayerBottomSpacer,
      ),
      child: AnimatedBuilder(
        animation: _horizontalOffset,
        builder: (context, child) => Transform.translate(
          offset: Offset(_horizontalOffset.value, 0),
          child: child,
        ),
        child: TweenAnimationBuilder<ColorScheme>(
          tween: _ColorSchemeTween(end: targetColors),
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
          builder: (context, colors, _) => Material(
            color: colors.primaryContainer,
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: .32),
            shape: useSmoothCorners
                ? RoundedSuperellipseBorder(
                    borderRadius: miniPlayerBorderRadius,
                  )
                : RoundedRectangleBorder(borderRadius: miniPlayerBorderRadius),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: controller.showFullPlayer,
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < -150) {
                  controller.showFullPlayer();
                }
              },
              onHorizontalDragStart: swipeToDismiss
                  ? _onHorizontalDragStart
                  : null,
              onHorizontalDragUpdate: swipeToDismiss
                  ? _onHorizontalDragUpdate
                  : null,
              onHorizontalDragEnd: swipeToDismiss ? _onHorizontalDragEnd : null,
              child: SizedBox(
                height: miniPlayerHeight,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 12),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Artwork(
                            colors: song.colors,
                            size: 44,
                            borderRadius: 22,
                            iconSize: 17,
                            mediaStoreId: song.mediaStoreId,
                          ),
                          if (castConnecting)
                            SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AutoScrollingText(
                              text: castConnecting
                                  ? 'Connecting to device…'
                                  : song.title,
                              style: TextStyle(
                                color: colors.onPrimaryContainer,
                                fontFamily: 'GoogleSansFlex',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.2,
                                height: 1.15,
                              ),
                              gradientEdgeColor: colors.primaryContainer,
                              canScroll: controller.isPlaying,
                            ),
                            const SizedBox(height: 2),
                            AutoScrollingText(
                              text: song.artist,
                              style: TextStyle(
                                color: colors.onPrimaryContainer.withValues(
                                  alpha: .7,
                                ),
                                fontFamily: 'GoogleSansFlex',
                                fontSize: 13,
                                letterSpacing: 0,
                                height: 1.15,
                              ),
                              gradientEdgeColor: colors.primaryContainer,
                              canScroll: controller.isPlaying,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _MiniControl(
                        enabled: !castConnecting,
                        background: colors.onPrimary,
                        foreground: colors.primary,
                        icon: Icons.skip_previous_rounded,
                        semanticLabel: 'Anterior',
                        onPressed: () {
                          if (controller.boolSetting(
                            'behavior_haptic_feedback',
                            true,
                          )) {
                            HapticFeedback.selectionClick();
                          }
                          controller.skipPrevious();
                        },
                      ),
                      const SizedBox(width: 8),
                      _MiniControl(
                        enabled: !castConnecting,
                        background: colors.primary,
                        foreground: colors.onPrimary,
                        icon: controller.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        semanticLabel: controller.isPlaying
                            ? 'Pausar'
                            : 'Reproducir',
                        onPressed: () {
                          if (controller.boolSetting(
                            'behavior_haptic_feedback',
                            true,
                          )) {
                            HapticFeedback.selectionClick();
                          }
                          controller.togglePlayPause();
                        },
                      ),
                      const SizedBox(width: 8),
                      _MiniControl(
                        enabled: !castConnecting,
                        background: colors.onPrimary,
                        foreground: colors.primary,
                        icon: Icons.skip_next_rounded,
                        semanticLabel: 'Siguiente',
                        onPressed: controller.skipNext,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSchemeTween extends Tween<ColorScheme> {
  _ColorSchemeTween({required ColorScheme end}) : super(end: end);

  @override
  ColorScheme lerp(double t) => ColorScheme.lerp(begin!, end!, t);
}

class _MiniControl extends StatelessWidget {
  const _MiniControl({
    this.enabled = true,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final bool enabled;
  final Color background;
  final Color foreground;
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: SizedBox.square(
        // Keep an accessible 44 dp hit target while matching the source's
        // 36 dp visible transport circles.
        dimension: 44,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: enabled ? onPressed : null,
            radius: 22,
            containedInkWell: false,
            customBorder: const CircleBorder(),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
