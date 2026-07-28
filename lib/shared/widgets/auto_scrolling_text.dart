import 'dart:async';

import 'package:flutter/material.dart';

class AutoScrollingText extends StatefulWidget {
  const AutoScrollingText({
    required this.text,
    required this.style,
    required this.gradientEdgeColor,
    this.gradientWidth = 24,
    this.canScroll = true,
    super.key,
  });

  final String text;
  final TextStyle style;
  final Color gradientEdgeColor;
  final double gradientWidth;
  final bool canScroll;

  @override
  State<AutoScrollingText> createState() => _AutoScrollingTextState();
}

class _AutoScrollingTextState extends State<AutoScrollingText>
    with SingleTickerProviderStateMixin {
  static const _initialDelay = Duration(milliseconds: 2000);
  static const _fadeDuration = Duration(milliseconds: 180);
  static const _velocity = 25.0;
  static const _spacing = 30.0;

  late final AnimationController _controller;
  Timer? _startTimer;
  double _lastTravel = 0;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant AutoScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.canScroll != widget.canScroll) {
      _reset();
    }
  }

  void _reset() {
    _startTimer?.cancel();
    _controller.stop();
    _controller.value = 0;
    _lastTravel = 0;
    if (_isScrolling) {
      setState(() => _isScrolling = false);
    }
  }

  void _schedule(double travel) {
    if (!widget.canScroll ||
        !travel.isFinite ||
        travel <= 0 ||
        travel == _lastTravel) {
      return;
    }
    _lastTravel = travel;
    _startTimer?.cancel();
    _controller.stop();
    _controller.value = 0;
    final milliseconds = ((travel / _velocity) * 1000).round();
    _controller.duration = Duration(milliseconds: milliseconds);
    _startTimer = Timer(_initialDelay, () {
      if (!mounted || !widget.canScroll) return;
      setState(() => _isScrolling = true);
      _controller.repeat();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        if (!availableWidth.isFinite || availableWidth <= 0) {
          return Text(
            widget.text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }

        final direction = Directionality.of(context);
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: direction,
        )..layout();

        final textHeight = painter.height > 0 ? painter.height : 24.0;
        final overflowing = painter.width > availableWidth;

        if (!overflowing) {
          return SizedBox(
            height: textHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.text,
                maxLines: 1,
                softWrap: false,
                style: widget.style,
              ),
            ),
          );
        }

        final travel = painter.width + _spacing;
        if (!travel.isFinite || travel <= 0) {
          return SizedBox(
            height: textHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: widget.style,
              ),
            ),
          );
        }

        if (widget.canScroll) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _schedule(travel),
          );
        }

        final textWidget = Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          style: widget.style,
        );

        final content = widget.canScroll
            ? SizedBox(
                height: textHeight,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final translateX = -travel * _controller.value;
                    return Transform.translate(
                      offset: Offset(translateX.isFinite ? translateX : 0, 0),
                      child: child,
                    );
                  },
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 0,
                    maxWidth: double.infinity,
                    minHeight: textHeight,
                    maxHeight: textHeight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        textWidget,
                        const SizedBox(width: _spacing),
                        textWidget,
                      ],
                    ),
                  ),
                ),
              )
            : SizedBox(
                height: textHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: textWidget,
                ),
              );

        final rawEdge = availableWidth > 0
            ? (widget.gradientWidth / availableWidth)
            : 0.0;
        final edge = (rawEdge.isFinite ? rawEdge : 0.0).clamp(0.0, 0.5);

        return RepaintBoundary(
          child: SizedBox(
            height: textHeight,
            child: ClipRect(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _isScrolling ? 1 : 0),
                duration: _fadeDuration,
                builder: (context, leftFade, child) {
                  final safeFade = leftFade.isFinite
                      ? leftFade.clamp(0.0, 1.0)
                      : 0.0;
                  return ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) {
                      if (bounds.isEmpty ||
                          !bounds.width.isFinite ||
                          !bounds.height.isFinite) {
                        return const LinearGradient(
                          colors: [Colors.black, Colors.black],
                        ).createShader(bounds);
                      }
                      return LinearGradient(
                        colors: [
                          Colors.black.withValues(
                            alpha: (1 - safeFade).clamp(0.0, 1.0),
                          ),
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0, edge, 1 - edge, 1],
                      ).createShader(bounds);
                    },
                    child: child,
                  );
                },
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }
}
