import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Flutter port of `presentation/screens/TabAnimation.kt`.
///
/// The selected tab briefly grows while its direct neighbours move away by
/// 12 logical pixels. Initial composition is deliberately static, matching
/// the source implementation.
class TabAnimation extends StatefulWidget {
  const TabAnimation({
    required this.index,
    required this.selectedIndex,
    required this.title,
    required this.onTap,
    required this.child,
    this.selectedColor,
    this.onSelectedColor,
    this.unselectedColor,
    this.onUnselectedColor,
    this.transformAlignment = Alignment.center,
    super.key,
  });

  final int index;
  final int selectedIndex;
  final String title;
  final VoidCallback onTap;
  final Widget child;
  final Color? selectedColor;
  final Color? onSelectedColor;
  final Color? unselectedColor;
  final Color? onUnselectedColor;
  final Alignment transformAlignment;

  @override
  State<TabAnimation> createState() => _TabAnimationState();
}

class _TabAnimationState extends State<TabAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hasAnimatedSelectionChange = false;
  double _neighbourDirection = 0;

  bool get _selected => widget.index == widget.selectedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didUpdateWidget(covariant TabAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex == widget.selectedIndex) return;
    if (!_hasAnimatedSelectionChange) {
      _hasAnimatedSelectionChange = true;
      return;
    }
    final distance = widget.index - widget.selectedIndex;
    _neighbourDirection = !_selected && distance.abs() == 1
        ? distance.sign.toDouble()
        : 0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedBackground = widget.selectedColor ?? colors.primary;
    final selectedForeground = widget.onSelectedColor ?? colors.onPrimary;
    final unselectedBackground = widget.unselectedColor ?? colors.surface;
    final unselectedForeground =
        widget.onUnselectedColor ?? colors.onSurface.withValues(alpha: .9);

    return Padding(
      padding: const EdgeInsets.all(5),
      child: AnimatedBuilder(
        animation: _controller,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.linear,
          constraints: const BoxConstraints(minHeight: 40),
          decoration: ShapeDecoration(
            color: _selected ? selectedBackground : unselectedBackground,
            shape: const StadiumBorder(),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onTap();
              },
              customBorder: const StadiumBorder(),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: _selected ? selectedForeground : unselectedForeground,
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: _selected
                        ? selectedForeground
                        : unselectedForeground,
                  ),
                  child: Center(child: widget.child),
                ),
              ),
            ),
          ),
        ),
        builder: (context, child) {
          final progress = Curves.fastOutSlowIn.transform(_controller.value);
          final double pulse = progress <= .5
              ? progress * 2
              : (1 - progress) * 2;
          final double scale = _selected ? 1 + .05 * pulse : 1;
          final double offset = _selected
              ? 0
              : 12 * _neighbourDirection * pulse;
          return Semantics(
            button: true,
            selected: _selected,
            label: widget.title,
            child: Transform(
              alignment: widget.transformAlignment,
              transform: Matrix4.identity()
                ..translateByDouble(offset, 0.0, 0.0, 1.0)
                ..scaleByDouble(scale, scale, 1.0, 1.0),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
