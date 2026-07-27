import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Material 3 Expressive Loading Indicator
/// Inspired by Android 15 / Material 3 Expressive `ContainedLoadingIndicator`.
class M3ExpressiveLoadingIndicator extends StatefulWidget {
  const M3ExpressiveLoadingIndicator({
    super.key,
    this.size = 36,
    this.contained = false,
    this.color,
  });

  final double size;
  final bool contained;
  final Color? color;

  @override
  State<M3ExpressiveLoadingIndicator> createState() =>
      _M3ExpressiveLoadingIndicatorState();
}

class _M3ExpressiveLoadingIndicatorState
    extends State<M3ExpressiveLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = widget.color ?? theme.colorScheme.primary;

    Widget child = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final rotation = progress * 2 * math.pi;
        final morphScale = 0.88 + 0.12 * math.sin(progress * 2 * math.pi);

        return Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: morphScale,
            child: SizedBox.square(
              dimension: widget.size,
              child: CircularProgressIndicator(
                strokeWidth: math.max(2.8, widget.size / 9),
                color: indicatorColor,
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
        );
      },
    );

    if (widget.contained) {
      child = Container(
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: child,
      );
    }

    return child;
  }
}
