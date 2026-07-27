import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/song.dart';
import '../../../core/state/app_controller.dart';
import '../../../shared/widgets/artwork.dart';
import '../../../shared/widgets/auto_scrolling_text.dart';

/// Source-faithful port of `LibraryPlaybackAwareSongItem.kt` and the visual
/// states it delegates to in `EnhancedSongListItem.kt`.
class LibraryPlaybackAwareSongItem extends StatelessWidget {
  const LibraryPlaybackAwareSongItem({
    required this.song,
    required this.onMoreOptionsClick,
    required this.onTap,
    this.albumArtSize = 50,
    this.isSelected = false,
    this.selectionIndex,
    this.isSelectionMode = false,
    this.onLongPress,
    super.key,
  });

  final Song song;
  final double albumArtSize;
  final bool isSelected;
  final int? selectionIndex;
  final bool isSelectionMode;
  final VoidCallback? onLongPress;
  final ValueChanged<Song> onMoreOptionsClick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final isCurrentSong = controller.currentSong?.id == song.id;
    final isPlaying = isCurrentSong && controller.isPlaying;
    final colors = Theme.of(context).colorScheme;
    final highlighted = isCurrentSong;
    final containerColor = isSelected
        ? colors.secondaryContainer
        : highlighted
        ? colors.primaryContainer
        : colors.surfaceContainerLow;
    final contentColor = isSelected
        ? colors.onSecondaryContainer
        : highlighted
        ? colors.onPrimaryContainer
        : colors.onSurface;
    final radius = highlighted ? 50.0 : 22.0;
    final albumRadius = highlighted ? 50.0 : 10.0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedScale(
      scale: isSelected ? .98 : 1,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: reduceMotion
            ? Duration.zero
            : Duration(milliseconds: isSelected ? 250 : 400),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(radius),
          border: isSelected
              ? Border.all(color: colors.primary, width: 2.5)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isSelectionMode ? onLongPress : onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              child: Row(
                children: [
                  _SelectableArtwork(
                    song: song,
                    size: albumArtSize,
                    radius: albumRadius,
                    selected: isSelected,
                    selectionIndex: selectionIndex,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (highlighted && !isSelectionMode)
                          AutoScrollingText(
                            text: song.title,
                            style: (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
                                .copyWith(
                                  color: contentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                            gradientEdgeColor: containerColor,
                            canScroll: isPlaying,
                          )
                        else
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: contentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: contentColor.withValues(alpha: .7),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrentSong && !isSelectionMode) ...[
                    const SizedBox(width: 8),
                    _PlayingEqIcon(color: contentColor, isPlaying: isPlaying),
                  ],
                  if (!isSelectionMode) ...[
                    const SizedBox(width: 12),
                    SizedBox.square(
                      dimension: 40,
                      child: IconButton.filled(
                        onPressed: () => onMoreOptionsClick(song),
                        style: IconButton.styleFrom(
                          minimumSize: const Size.square(40),
                          padding: EdgeInsets.zero,
                          backgroundColor: highlighted
                              ? colors.onPrimaryContainer
                              : colors.onSurface,
                          foregroundColor: highlighted
                              ? colors.primaryContainer
                              : colors.surfaceContainerHigh,
                        ),
                        icon: const Icon(Icons.more_vert_rounded, size: 24),
                        tooltip: 'More options for ${song.title}',
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
}

class _SelectableArtwork extends StatelessWidget {
  const _SelectableArtwork({
    required this.song,
    required this.size,
    required this.radius,
    required this.selected,
    required this.selectionIndex,
  });

  final Song song;
  final double size;
  final double radius;
  final bool selected;
  final int? selectionIndex;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 400),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Artwork(
              colors: song.colors,
              size: size,
              borderRadius: radius,
              mediaStoreId: song.mediaStoreId,
            ),
          ),
          if (selected)
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Center(
                child: selectionIndex != null && selectionIndex! >= 0
                    ? Text(
                        '$selectionIndex',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      )
                    : Icon(
                        Icons.check_circle_rounded,
                        color: colors.onPrimary,
                        size: 28,
                        semanticLabel: 'Selected',
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayingEqIcon extends StatefulWidget {
  const _PlayingEqIcon({required this.color, required this.isPlaying});

  final Color color;
  final bool isPlaying;

  @override
  State<_PlayingEqIcon> createState() => _PlayingEqIconState();
}

class _PlayingEqIconState extends State<_PlayingEqIcon>
    with TickerProviderStateMixin {
  late final AnimationController _phase;
  late final AnimationController _activity;

  @override
  void initState() {
    super.initState();
    _phase = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _activity = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: widget.isPlaying ? 1 : 0,
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PlayingEqIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) _sync();
  }

  void _sync() {
    if (widget.isPlaying) {
      _phase.repeat();
      _activity.forward();
    } else {
      _phase.stop();
      _activity.reverse();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 16,
      child: AnimatedBuilder(
        animation: Listenable.merge([_phase, _activity]),
        builder: (context, _) => CustomPaint(
          painter: _EqualizerPainter(
            phase: _phase.value * math.pi * 2,
            activity: Curves.fastOutSlowIn.transform(_activity.value),
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  const _EqualizerPainter({
    required this.phase,
    required this.activity,
    required this.color,
  });

  final double phase;
  final double activity;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 3;
    const gapFraction = .3;
    final barWidth = size.width / (bars + (bars - 1) * (1 + gapFraction));
    final gap = barWidth * gapFraction;
    final paint = Paint()..color = color;
    for (var index = 0; index < bars; index++) {
      final raw = (math.sin(phase * (index + 1) + index * .9) + 1) / 2;
      final eased = raw * raw * (3 - 2 * raw);
      final liveHeight = size.height * (.28 + .72 * eased);
      final height = barWidth + (liveHeight - barWidth) * activity;
      final left = index * (barWidth + gap);
      final rect = Rect.fromLTWH(
        left,
        (size.height - height) / 2,
        barWidth,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerPainter oldDelegate) {
    return phase != oldDelegate.phase ||
        activity != oldDelegate.activity ||
        color != oldDelegate.color;
  }
}
