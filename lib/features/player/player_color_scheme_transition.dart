import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef PlayerColorSchemeWidgetBuilder =
    Widget Function(BuildContext context, ColorScheme colors, Widget? child);

/// Drives every player surface through the same album-color transition.
///
/// PixelPlayer's Compose implementation interpolates the whole [ColorScheme]
/// with one critically damped medium-low spring. Sharing this widget keeps the
/// mini player, expanded player, and lyrics screen on the same motion curve
/// when the current song changes.
class PlayerColorSchemeTransition extends StatefulWidget {
  const PlayerColorSchemeTransition({
    required this.target,
    required this.builder,
    this.child,
    super.key,
  });

  final ColorScheme target;
  final PlayerColorSchemeWidgetBuilder builder;
  final Widget? child;

  @override
  State<PlayerColorSchemeTransition> createState() =>
      _PlayerColorSchemeTransitionState();
}

class _PlayerColorSchemeTransitionState
    extends State<PlayerColorSchemeTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late ColorScheme _from;
  late ColorScheme _to;

  @override
  void initState() {
    super.initState();
    _from = widget.target;
    _to = widget.target;
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant PlayerColorSchemeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.target == _to) return;

    // Keep the in-flight colour as the next start.  A track switch can deliver
    // its fallback MediaStore colour and its extracted artwork colour in quick
    // succession; starting from the visible colour prevents the lyrics sheet
    // from snapping back to a previous track's Material You palette.
    final progress = const _MediumLowNoBounceSpringCurve().transform(
      _animation.value,
    );
    _from = ColorScheme.lerp(_from, _to, progress);
    _to = widget.target;
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else {
      _animation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _animation.value != 1) {
      _animation.value = 1;
    }
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final progress = reduceMotion
            ? 1.0
            : const _MediumLowNoBounceSpringCurve().transform(_animation.value);
        return widget.builder(
          context,
          ColorScheme.lerp(_from, _to, progress),
          child,
        );
      },
    );
  }
}

/// Step response for Compose's default non-bouncy spring at medium-low
/// stiffness (400). The 460 ms window reaches the settled target without the
/// abrupt end produced by a conventional cubic tween.
class _MediumLowNoBounceSpringCurve extends Curve {
  const _MediumLowNoBounceSpringCurve();

  static const _stiffness = 400.0;
  static const _responseSeconds = .46;

  @override
  double transformInternal(double t) {
    final angularFrequency = math.sqrt(_stiffness);
    final elapsed = t * _responseSeconds;
    return 1 -
        (1 + angularFrequency * elapsed) *
            math.exp(-angularFrequency * elapsed);
  }
}
