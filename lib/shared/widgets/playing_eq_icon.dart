import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Material 3 Expressive Playing EQ Visualizer Icon
/// Animates 3 vertical rounded bars with dynamic heights when [isPlaying] is true.
class PlayingEqIcon extends StatefulWidget {
  const PlayingEqIcon({
    super.key,
    this.width = 16.0,
    this.height = 15.0,
    this.color,
    this.isPlaying = true,
  });

  final double width;
  final double height;
  final Color? color;
  final bool isPlaying;

  @override
  State<PlayingEqIcon> createState() => _PlayingEqIconState();
}

class _PlayingEqIconState extends State<PlayingEqIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PlayingEqIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.color ?? Theme.of(context).colorScheme.primary;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * 2 * math.pi;
            final bar1 = widget.isPlaying
                ? (0.35 + 0.55 * (0.5 + 0.5 * math.sin(t)))
                : 0.35;
            final bar2 = widget.isPlaying
                ? (0.25 + 0.70 * (0.5 + 0.5 * math.sin(t + 2.1)))
                : 0.75;
            final bar3 = widget.isPlaying
                ? (0.38 + 0.57 * (0.5 + 0.5 * math.sin(t + 4.2)))
                : 0.45;
            final bars = [bar1, bar2, bar3];

            return CustomPaint(
              painter: _EqPainter(bars: bars, color: barColor),
            );
          },
        ),
      ),
    );
  }
}

class _EqPainter extends CustomPainter {
  const _EqPainter({required this.bars, required this.color});

  final List<double> bars;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final barCount = bars.length;
    final totalSpacing = size.width * 0.32;
    final barWidth = (size.width - totalSpacing) / barCount;
    final gap = totalSpacing / (barCount - 1);
    final radius = Radius.circular(barWidth / 2);

    for (var i = 0; i < barCount; i++) {
      final fraction = bars[i].clamp(0.25, 1.0);
      final barHeight = size.height * fraction;
      final left = i * (barWidth + gap);
      final top = (size.height - barHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        radius,
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.bars != bars;
}
