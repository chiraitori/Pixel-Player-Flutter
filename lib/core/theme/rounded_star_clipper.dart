import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Flutter port of PixelPlay's Compose `RoundedStarShape`.
///
/// The original shape is a smooth radial wave rather than a conventional
/// pointed star. Keeping the same equation and sample count makes expressive
/// badges occupy the same visual bounds on both implementations.
class RoundedStarClipper extends CustomClipper<Path> {
  const RoundedStarClipper({
    required this.sides,
    this.curve = .09,
    this.rotation = 0,
    this.iterations = 360,
  }) : assert(sides > 0),
       assert(curve >= 0 && curve <= 1),
       assert(iterations > 0);

  final int sides;
  final double curve;
  final double rotation;
  final int iterations;

  @override
  Path getClip(Size size) {
    final shortestSide = math.min(size.width, size.height);
    final radius = shortestSide * .4 * (1 - curve * .5);
    final center = Offset(size.width * .5, size.height * .5);
    final rotationRadians = math.pi / 180 * rotation;
    final step = math.pi * 2 / math.min(iterations, 360);

    Offset pointAt(double t) {
      final wave = 1 + curve * math.cos(sides * t);
      return Offset(
        center.dx + radius * math.cos(t - rotationRadians) * wave,
        center.dy + radius * math.sin(t - rotationRadians) * wave,
      );
    }

    final first = pointAt(0);
    final path = Path()..moveTo(first.dx, first.dy);
    for (var t = step; t < math.pi * 2; t += step) {
      final point = pointAt(t);
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant RoundedStarClipper oldClipper) =>
      sides != oldClipper.sides ||
      curve != oldClipper.curve ||
      rotation != oldClipper.rotation ||
      iterations != oldClipper.iterations;
}
