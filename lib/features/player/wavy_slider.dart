import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.waveAmplitude = 3.5,
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
  late final AnimationController _progressTween;

  double _renderedProgress = 0.0;
  double _targetProgress = 0.0;
  double? _gestureValue;
  int _lastHapticStep = -1;
  double _lastSeekTarget = -1.0;
  DateTime? _lastSeekTime;
  bool _disableAnimations = false;

  double get _currentValue => (_gestureValue ?? _renderedProgress).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _renderedProgress = widget.value.clamp(0.0, 1.0);
    _targetProgress = _renderedProgress;

    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _interaction = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _progressTween = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(_onProgressTick);

    _syncWave();
  }

  void _onProgressTick() {
    if (_gestureValue != null) return;
    setState(() {
      _renderedProgress = _renderedProgress +
          (_targetProgress - _renderedProgress) * _progressTween.value;
    });
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

    if (_gestureValue == null) {
      final newTarget = widget.value.clamp(0.0, 1.0);

      // Check if seek was recent and audio engine hasn't caught up yet
      if (_lastSeekTarget >= 0 && _lastSeekTime != null) {
        final elapsed = DateTime.now().difference(_lastSeekTime!).inMilliseconds;
        final diff = (newTarget - _lastSeekTarget).abs();
        if (elapsed < 3000 && diff > 0.04) {
          // Keep current target while waiting for engine catch-up
          return;
        } else {
          _lastSeekTarget = -1.0;
        }
      }

      // If big jump (song change / manual seek), snap immediately
      if ((newTarget - _renderedProgress).abs() > 0.12) {
        setState(() {
          _targetProgress = newTarget;
          _renderedProgress = newTarget;
        });
      } else if ((newTarget - _targetProgress).abs() > 0.0005) {
        _targetProgress = newTarget;
        _progressTween.forward(from: 0.0);
      }
    }
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
    _progressTween.dispose();
    super.dispose();
  }

  double _valueForX(double x, double width) {
    final padding = widget.trackEdgePadding.clamp(0, width / 2);
    return ((x - padding) / math.max(1, width - padding * 2)).clamp(0, 1);
  }

  void _start(Offset localPosition, double width) {
    _interaction.forward();
    final val = _valueForX(localPosition.dx, width);
    _lastHapticStep = (val * 20).round();
    setState(() {
      _gestureValue = val;
      _renderedProgress = val;
    });
    widget.onChanged(val);
  }

  void _update(Offset localPosition, double width) {
    final val = _valueForX(localPosition.dx, width);
    final step = (val * 20).round();
    if (step != _lastHapticStep) {
      _lastHapticStep = step;
      HapticFeedback.selectionClick();
    }

    setState(() {
      _gestureValue = val;
      _renderedProgress = val;
    });
    widget.onChanged(val);
  }

  void _finish() {
    final val = _currentValue;
    _lastSeekTarget = val;
    _lastSeekTime = DateTime.now();
    widget.onChangeEnd(val);
    setState(() {
      _gestureValue = null;
      _targetProgress = val;
      _renderedProgress = val;
    });
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
      value: '${(_currentValue * 100).round()}%',
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
              animation: Listenable.merge([_wave, _interaction, _progressTween]),
              builder: (context, child) => CustomPaint(
                painter: _WavySliderPainter(
                  value: _currentValue,
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
                  amplitude: widget.isPlaying &&
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
    final thumbHeight =
        thumbRadius * 2 * (1 - interaction) +
        interactingThumbHeight * interaction;
    final gap = 6.0 + (thumbWidth / 2 + 1.2 - 6.0) * interaction;

    // 1. Draw Active Wave Track (stops cleanly before the thumb gap)
    final activeEnd = math.max(start, thumbX - thumbWidth / 2 - gap);
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

    // 2. Draw Inactive Track (starts after thumb gap)
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = strokeWidth * 0.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final inactiveStart = math.min(end, thumbX + thumbWidth / 2 + gap);
    if (inactiveStart < end) {
      canvas.drawLine(
        Offset(inactiveStart, centerY),
        Offset(end - 3, centerY),
        inactivePaint,
      );
      // Draw stop dot at the end of the inactive track
      canvas.drawCircle(
        Offset(end, centerY),
        strokeWidth * 0.45,
        Paint()..color = inactiveColor.withValues(alpha: math.min(1.0, inactiveColor.a * 1.8)),
      );
    }

    // 3. Draw Thumb (Morphs from circle to tall capsule bar)
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
