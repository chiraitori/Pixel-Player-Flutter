import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

const double navBarContentHeight = 90;
const double navBarCompactContentHeight = 64;
const double maxNavigationBarBottomInset = 96;

enum PixelNavBarStyle { floating, fullWidth }

double sanitizeNavigationBarBottomInset(double value) {
  if (!value.isFinite) return 0;
  return value.clamp(0, maxNavigationBarBottomInset);
}

double resolveNavBarContentHeight(bool compactMode) {
  return compactMode ? navBarCompactContentHeight : navBarContentHeight;
}

double resolveNavBarSurfaceHeight({
  required PixelNavBarStyle style,
  required double systemInset,
  required bool compactMode,
}) {
  final contentHeight = resolveNavBarContentHeight(compactMode);
  return style == PixelNavBarStyle.fullWidth
      ? contentHeight + sanitizeNavigationBarBottomInset(systemInset)
      : contentHeight;
}

double resolveNavBarOccupiedHeight({
  required double systemInset,
  required bool compactMode,
}) {
  return resolveNavBarContentHeight(compactMode) +
      sanitizeNavigationBarBottomInset(systemInset);
}

class PlayerInternalNavigationBar extends StatefulWidget {
  const PlayerInternalNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onSearchDoubleTap,
    required this.style,
    required this.compactMode,
    this.enabled = true,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSearchDoubleTap;
  final PixelNavBarStyle style;
  final bool compactMode;
  final bool enabled;

  @override
  State<PlayerInternalNavigationBar> createState() {
    return _PlayerInternalNavigationBarState();
  }
}

class _PlayerInternalNavigationBarState
    extends State<PlayerInternalNavigationBar> {
  DateTime? _lastSearchTap;

  static const destinations = <_NavDestination>[
    _NavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavDestination(
      label: 'Search',
      icon: Icons.search_rounded,
      selectedIcon: Icons.search_rounded,
    ),
    _NavDestination(
      label: 'Library',
      icon: Icons.library_music_outlined,
      selectedIcon: Icons.library_music_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final rawInset = MediaQuery.viewPaddingOf(context).bottom;
    final systemInset = sanitizeNavigationBarBottomInset(rawInset);
    final innerBottomPadding = widget.style == PixelNavBarStyle.fullWidth
        ? systemInset
        : 0.0;
    final horizontalPadding = widget.style == PixelNavBarStyle.fullWidth
        ? 12.0
        : 10.0;
    return SizedBox(
      height: resolveNavBarSurfaceHeight(
        style: widget.style,
        systemInset: systemInset,
        compactMode: widget.compactMode,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          0,
          horizontalPadding,
          innerBottomPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < destinations.length; index++)
              Expanded(
                child: _CustomNavigationBarItem(
                  destination: destinations[index],
                  selected: widget.selectedIndex == index,
                  enabled: widget.enabled,
                  compactMode: widget.compactMode,
                  onTap: () => _handleTap(index),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleTap(int index) {
    if (!widget.enabled) {
      _lastSearchTap = null;
      return;
    }
    final alreadySelected = widget.selectedIndex == index;
    if (index == 1) {
      final now = DateTime.now();
      final doubleTap =
          _lastSearchTap != null &&
          now.difference(_lastSearchTap!).inMilliseconds <= 350;
      _lastSearchTap = now;
      if (!alreadySelected) widget.onDestinationSelected(index);
      if (doubleTap) {
        _lastSearchTap = null;
        if (alreadySelected) {
          widget.onSearchDoubleTap();
        } else {
          Future<void>.delayed(
            const Duration(milliseconds: 160),
            widget.onSearchDoubleTap,
          );
        }
      }
      return;
    }
    _lastSearchTap = null;
    if (!alreadySelected) widget.onDestinationSelected(index);
  }
}

class _CustomNavigationBarItem extends StatefulWidget {
  const _CustomNavigationBarItem({
    required this.destination,
    required this.selected,
    required this.enabled,
    required this.compactMode,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool selected;
  final bool enabled;
  final bool compactMode;
  final VoidCallback onTap;

  @override
  State<_CustomNavigationBarItem> createState() =>
      _CustomNavigationBarItemState();
}

class _CustomNavigationBarItemState extends State<_CustomNavigationBarItem>
    with TickerProviderStateMixin {
  late final AnimationController _indicatorOpacity;
  late final AnimationController _indicatorScale;
  late final AnimationController _iconScale;

  static const _indicatorSpring = SpringDescription(
    mass: 1,
    stiffness: 200,
    damping: 14.15,
  );
  static const _iconSpring = SpringDescription(
    mass: 1,
    // CustomNavigationBarItem.kt uses Spring.StiffnessMedium with
    // DampingRatioMediumBouncy for the selected-icon scale.  The previous
    // critically damped 1500 spring made navigation selection look flatter
    // than the Compose Material 3 Expressive response.
    stiffness: 500,
    damping: 22.3607,
  );

  @override
  void initState() {
    super.initState();
    _indicatorOpacity = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 100),
      value: widget.selected ? 1 : 0,
    );
    _indicatorScale = AnimationController.unbounded(
      vsync: this,
      value: widget.selected ? 1 : 0,
    );
    _iconScale = AnimationController.unbounded(
      vsync: this,
      value: widget.selected ? 1.1 : 1,
    );
  }

  @override
  void didUpdateWidget(covariant _CustomNavigationBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _animateSelection();
  }

  void _animateSelection() {
    if (widget.selected) {
      _indicatorOpacity.forward();
      _indicatorScale.animateWith(
        SpringSimulation(_indicatorSpring, _indicatorScale.value, 1, 0),
      );
    } else {
      _indicatorOpacity.reverse();
      _indicatorScale.animateTo(
        0,
        duration: const Duration(milliseconds: 100),
        curve: const Cubic(0.5, 0, 0.75, 0),
      );
    }
    _iconScale.animateWith(
      SpringSimulation(
        _iconSpring,
        _iconScale.value,
        widget.selected ? 1.1 : 1,
        0,
      ),
    );
  }

  @override
  void dispose() {
    _indicatorOpacity.dispose();
    _indicatorScale.dispose();
    _iconScale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconColor = widget.selected
        ? colors.primary
        : colors.onSurfaceVariant;
    final textColor = widget.selected
        ? colors.primary
        : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.destination.label,
      child: InkWell(
        onTap: widget.enabled ? widget.onTap : null,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FadeTransition(
                    opacity: _indicatorOpacity,
                    child: AnimatedBuilder(
                      animation: _indicatorScale,
                      builder: (context, child) => Transform.scale(
                        scale: _indicatorScale.value,
                        child: child,
                      ),
                      child: Container(
                        width: 56,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _iconScale,
                    builder: (context, child) =>
                        Transform.scale(scale: _iconScale.value, child: child),
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: iconColor),
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        widget.selected
                            ? widget.destination.selectedIcon
                            : widget.destination.icon,
                        size: 24,
                      ),
                      builder: (context, color, child) => IconTheme(
                        data: IconThemeData(color: color),
                        child: child!,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.compactMode) ...[
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: widget.selected
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
                child: Text(widget.destination.label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
