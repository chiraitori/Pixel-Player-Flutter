import 'dart:math' as math;

import 'package:flutter/material.dart';

class WavySlider extends StatefulWidget {
  const WavySlider({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
    required this.isPlaying,
    this.strokeWidth = 5,
    this.thumbRadius = 8,
    this.trackEdgePadding = 8,
    this.wavelength = 24,
    this.waveAmplitude = 4,
    this.interactingThumbHeight = 24,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;
  final bool isPlaying;
  final double strokeWidth;
  final double thumbRadius;
  final double trackEdgePadding;
  final double wavelength;
  final double waveAmplitude;
  final double interactingThumbHeight;

  @override
  State<WavySlider> createState() => _WavySliderState();
}

class _WavySliderState extends State<WavySlider> with TickerProviderStateMixin {
  late final AnimationController _wave;
  late final AnimationController _interaction;
  double? _gestureValue;
  bool _disableAnimations = false;

  double get _value => (_gestureValue ?? widget.value).clamp(0, 1);

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _interaction = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _syncWave();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MediaQuery.disableAnimationsOf(context);
    if (next == _disableAnimations) return;
    _disableAnimations = next;
    _syncWave();
  }

  @override
  void didUpdateWidget(covariant WavySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) _syncWave();
  }

  void _syncWave() {
    if (widget.isPlaying && !_disableAnimations) {
      _wave.repeat();
    } else {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    _interaction.dispose();
    super.dispose();
  }

  double _valueForX(double x, double width) {
    final padding = widget.trackEdgePadding.clamp(0, width / 2);
    return ((x - padding) / math.max(1, width - padding * 2)).clamp(0, 1);
  }

  void _start(Offset localPosition, double width) {
    _interaction.forward();
    final value = _valueForX(localPosition.dx, width);
    setState(() => _gestureValue = value);
    widget.onChanged(value);
  }

  void _update(Offset localPosition, double width) {
    final value = _valueForX(localPosition.dx, width);
    setState(() => _gestureValue = value);
    widget.onChanged(value);
  }

  void _finish() {
    final value = _value;
    widget.onChangeEnd(value);
    setState(() => _gestureValue = null);
    _interaction.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final height = math.max(
      24.0,
      math.max(widget.thumbRadius * 2, widget.interactingThumbHeight),
    );
    return Semantics(
      slider: true,
      label: 'Playback position',
      value: '${(_value * 100).round()}%',
      increasedValue: '${((_value + .01).clamp(0, 1) * 100).round()}%',
      decreasedValue: '${((_value - .01).clamp(0, 1) * 100).round()}%',
      onIncrease: () {
        final value = (_value + .01).clamp(0.0, 1.0);
        widget.onChanged(value);
        widget.onChangeEnd(value);
      },
      onDecrease: () {
        final value = (_value - .01).clamp(0.0, 1.0);
        widget.onChanged(value);
        widget.onChangeEnd(value);
      },
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) =>
                _start(details.localPosition, constraints.maxWidth),
            onPanUpdate: (details) =>
                _update(details.localPosition, constraints.maxWidth),
            onPanEnd: (_) => _finish(),
            onPanCancel: _finish,
            child: AnimatedBuilder(
              animation: Listenable.merge([_wave, _interaction]),
              builder: (context, child) => CustomPaint(
                painter: _WavySliderPainter(
                  value: _value,
                  wavePhase: _wave.value,
                  interaction: Curves.fastOutSlowIn.transform(
                    _interaction.value,
                  ),
                  activeColor: widget.activeColor,
                  inactiveColor: widget.inactiveColor,
                  thumbColor: widget.thumbColor,
                  strokeWidth: widget.strokeWidth,
                  thumbRadius: widget.thumbRadius,
                  edgePadding: widget.trackEdgePadding,
                  wavelength: widget.wavelength,
                  amplitude:
                      widget.isPlaying &&
                          !_disableAnimations &&
                          _gestureValue == null
                      ? widget.waveAmplitude
                      : 0,
                  interactingThumbHeight: widget.interactingThumbHeight,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavySliderPainter extends CustomPainter {
  const _WavySliderPainter({
    required this.value,
    required this.wavePhase,
    required this.interaction,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbColor,
    required this.strokeWidth,
    required this.thumbRadius,
    required this.edgePadding,
    required this.wavelength,
    required this.amplitude,
    required this.interactingThumbHeight,
  });

  final double value;
  final double wavePhase;
  final double interaction;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbColor;
  final double strokeWidth;
  final double thumbRadius;
  final double edgePadding;
  final double wavelength;
  final double amplitude;
  final double interactingThumbHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final start = edgePadding.clamp(0.0, size.width / 2);
    final end = size.width - start;
    final width = math.max(0, end - start);
    final centerY = size.height / 2;
    final thumbX = start + width * value;
    final thumbWidth =
        thumbRadius * 2 * (1 - interaction) + strokeWidth * 1.2 * interaction;
    final thumbRadiusCurrent = thumbWidth / 2;
    final gap = 10.0 + 4.0 * interaction;

    // 1. Draw Active Wave Track (connects seamlessly to the thumb)
    final activeEnd = math.max(start, thumbX);
    if (activeEnd > start) {
      final activePaint = Paint()
        ..color = activeColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      const step = 1.5;
      for (double x = start; x <= activeEnd; x += step) {
        final radians =
            ((x - start) / wavelength - wavePhase) * math.pi * 2;
        final y = centerY + math.sin(radians) * amplitude;
        if (x == start) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, activePaint);
    }

    // 2. Draw Inactive Track (starts after a distinct GAP from the thumb)
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = strokeWidth * 0.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final inactiveStart = math.min(end, thumbX + thumbRadiusCurrent + gap);
    if (inactiveStart < end) {
      canvas.drawLine(
        Offset(inactiveStart, centerY),
        Offset(end - 3, centerY),
        inactivePaint,
      );
      // Draw stop dot at the end of the inactive track (Material 3 Expressive style)
      canvas.drawCircle(
        Offset(end, centerY),
        strokeWidth * 0.45,
        Paint()..color = inactiveColor.withValues(alpha: math.min(1.0, inactiveColor.a * 1.8)),
      );
    }

    final thumbHeight =
        thumbRadius * 2 * (1 - interaction) +
        interactingThumbHeight * interaction;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(thumbX, centerY),
          width: thumbWidth,
          height: thumbHeight,
        ),
        Radius.circular(thumbWidth / 2),
      ),
      Paint()..color = thumbColor,
    );
  }

  @override
  bool shouldRepaint(covariant _WavySliderPainter oldDelegate) {
    return value != oldDelegate.value ||
        wavePhase != oldDelegate.wavePhase ||
        interaction != oldDelegate.interaction ||
        activeColor != oldDelegate.activeColor ||
        inactiveColor != oldDelegate.inactiveColor ||
        thumbColor != oldDelegate.thumbColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        thumbRadius != oldDelegate.thumbRadius ||
        edgePadding != oldDelegate.edgePadding ||
        wavelength != oldDelegate.wavelength ||
        amplitude != oldDelegate.amplitude ||
        interactingThumbHeight != oldDelegate.interactingThumbHeight;
  }
}
