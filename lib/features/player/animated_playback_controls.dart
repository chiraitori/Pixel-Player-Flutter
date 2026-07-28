import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _PlaybackButtonType { previous, playPause, next }

/// Flutter equivalent of Material 3 Expressive's fast spatial spring.
///
/// Compose uses a spring with stiffness 800 and damping ratio 0.6 for these
/// transport controls. Keeping that response here preserves the small
/// overshoot when a button expands instead of flattening it into an easing
/// curve.
class _ExpressiveFastSpatialCurve extends Curve {
  const _ExpressiveFastSpatialCurve();

  static const _stiffness = 800.0;
  static const _dampingRatio = .6;
  static const _responseSeconds = .36;

  @override
  double transformInternal(double t) {
    final angularFrequency = math.sqrt(_stiffness);
    final dampedFrequency =
        angularFrequency * math.sqrt(1 - _dampingRatio * _dampingRatio);
    final elapsed = t * _responseSeconds;
    final decay = math.exp(-_dampingRatio * angularFrequency * elapsed);
    final response =
        1 -
        decay *
            (math.cos(dampedFrequency * elapsed) +
                (_dampingRatio * angularFrequency / dampedFrequency) *
                    math.sin(dampedFrequency * elapsed));
    return response;
  }
}

class AnimatedPlaybackControls extends StatefulWidget {
  const AnimatedPlaybackControls({
    required this.isPlaying,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.colorPrevious,
    required this.colorPlayPause,
    required this.colorNext,
    required this.tintPrevious,
    required this.tintPlayPause,
    required this.tintNext,
    this.hapticFeedbackEnabled = true,
    this.height = 80,
    super.key,
  });

  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final Color colorPrevious;
  final Color colorPlayPause;
  final Color colorNext;
  final Color tintPrevious;
  final Color tintPlayPause;
  final Color tintNext;
  final bool hapticFeedbackEnabled;
  final double height;

  @override
  State<AnimatedPlaybackControls> createState() =>
      _AnimatedPlaybackControlsState();
}

class _AnimatedPlaybackControlsState extends State<AnimatedPlaybackControls> {
  _PlaybackButtonType? _lastClicked;
  Timer? _releaseTimer;
  bool? _pendingPlayingState;
  late bool _visualPlaying;

  @override
  void initState() {
    super.initState();
    _visualPlaying = widget.isPlaying;
  }

  @override
  void didUpdateWidget(covariant AnimatedPlaybackControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying == widget.isPlaying) return;
    final locked =
        _lastClicked == _PlaybackButtonType.previous ||
        _lastClicked == _PlaybackButtonType.next;
    if (locked) {
      _pendingPlayingState = widget.isPlaying;
    } else {
      _visualPlaying = widget.isPlaying;
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  void _press(_PlaybackButtonType button) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() => _lastClicked = button);
    _releaseTimer?.cancel();
    final releaseDelay = reduceMotion
        ? Duration.zero
        : button == _PlaybackButtonType.previous ||
              button == _PlaybackButtonType.next
        ? const Duration(milliseconds: 600)
        : const Duration(milliseconds: 220);
    _releaseTimer = Timer(releaseDelay, () {
      if (!mounted) return;
      setState(() {
        _lastClicked = null;
        if (_pendingPlayingState case final pending?) {
          _visualPlaying = pending;
          _pendingPlayingState = null;
        }
      });
    });

    switch (button) {
      case _PlaybackButtonType.previous:
        Timer(
          reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          () {
            if (mounted) widget.onPrevious();
          },
        );
      case _PlaybackButtonType.playPause:
        if (widget.hapticFeedbackEnabled) HapticFeedback.selectionClick();
        widget.onPlayPause();
      case _PlaybackButtonType.next:
        Timer(
          reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          () {
            if (mounted) widget.onNext();
          },
        );
    }
  }

  double _weight(_PlaybackButtonType button) {
    if (_lastClicked == null) return 1.0;
    return _lastClicked == button ? 1.1 : .65;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final available = constraints.maxWidth - gap * 2;
        final previousWeight = _weight(_PlaybackButtonType.previous);
        final playWeight = _weight(_PlaybackButtonType.playPause);
        final nextWeight = _weight(_PlaybackButtonType.next);
        final totalWeight = previousWeight + playWeight + nextWeight;

        return SizedBox(
          height: widget.height,
          child: Row(
            children: [
              _AnimatedTransportButton(
                width: available * previousWeight / totalWeight,
                height: widget.height,
                radius: widget.height / 2,
                smoothShape: false,
                color: widget.colorPrevious,
                iconColor: widget.tintPrevious,
                icon: Icons.skip_previous_rounded,
                iconSize: 32,
                label: 'Anterior',
                reduceMotion: reduceMotion,
                onTap: () => _press(_PlaybackButtonType.previous),
              ),
              const SizedBox(width: gap),
              _AnimatedTransportButton(
                width: available * playWeight / totalWeight,
                height: widget.height,
                radius: _visualPlaying ? 26 : 60,
                smoothShape: true,
                color: widget.colorPlayPause,
                iconColor: widget.tintPlayPause,
                icon: _visualPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                iconSize: 36,
                label: _visualPlaying ? 'Pausar' : 'Reproducir',
                reduceMotion: reduceMotion,
                onTap: () => _press(_PlaybackButtonType.playPause),
              ),
              const SizedBox(width: gap),
              _AnimatedTransportButton(
                width: available * nextWeight / totalWeight,
                height: widget.height,
                radius: widget.height / 2,
                smoothShape: false,
                color: widget.colorNext,
                iconColor: widget.tintNext,
                icon: Icons.skip_next_rounded,
                iconSize: 32,
                label: 'Siguiente',
                reduceMotion: reduceMotion,
                onTap: () => _press(_PlaybackButtonType.next),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedTransportButton extends StatelessWidget {
  const _AnimatedTransportButton({
    required this.width,
    required this.height,
    required this.radius,
    required this.smoothShape,
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.reduceMotion,
    required this.onTap,
  });

  final double width;
  final double height;
  final double radius;
  final bool smoothShape;
  final Color color;
  final Color iconColor;
  final IconData icon;
  final double iconSize;
  final String label;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 360),
      curve: const _ExpressiveFastSpatialCurve(),
      width: width,
      height: height,
      decoration: ShapeDecoration(
        color: color,
        shape: smoothShape
            ? (radius >= 50
                  ? const StadiumBorder()
                  : RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(radius),
                    ))
            : const StadiumBorder(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              switchInCurve: Curves.fastOutSlowIn,
              switchOutCurve: Curves.fastOutSlowIn,
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: iconSize,
                color: iconColor,
                semanticLabel: label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
