import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/state/app_controller.dart';
import '../shell/player_internal_navigation_bar.dart';

const double _defaultNavBarCornerRadius = 28;

class NavBarCornerRadiusScreen extends StatefulWidget {
  const NavBarCornerRadiusScreen({super.key});

  @override
  State<NavBarCornerRadiusScreen> createState() =>
      _NavBarCornerRadiusScreenState();
}

class _NavBarCornerRadiusScreenState extends State<NavBarCornerRadiusScreen> {
  double _radius = _defaultNavBarCornerRadius;
  bool _initialized = false;

  bool get _hasBeenAdjusted => _radius != _defaultNavBarCornerRadius;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _radius = AppScope.of(context).navBarCornerRadius.clamp(0, 60);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final fullWidth = controller.navBarStyle == PixelNavBarStyle.fullWidth;
    final systemInset = sanitizeNavigationBarBottomInset(
      MediaQuery.viewPaddingOf(context).bottom,
    );
    final previewHeight = resolveNavBarSurfaceHeight(
      style: controller.navBarStyle,
      systemInset: systemInset,
      compactMode: controller.navBarCompactMode,
    );
    final smooth = controller.boolSetting('appearance_smooth_corners', true);

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: IconButton.filled(
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: colors.surfaceContainerLow,
              foregroundColor: colors.onSurface,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              controller.setNavBarCornerRadius(_radius.roundToDouble());
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Done'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: fullWidth ? 0 : systemInset),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Adjust navigation bar',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fine-tune the corner radius and preview it at full size.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 32),
                    color: colors.surfaceContainerLow,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Corner radius',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _hasBeenAdjusted
                                    ? SizedBox(
                                        key: const ValueKey('reset-radius'),
                                        height: 32,
                                        child: FilledButton.tonalIcon(
                                          onPressed: () {
                                            HapticFeedback.heavyImpact();
                                            setState(() {
                                              _radius =
                                                  _defaultNavBarCornerRadius;
                                            });
                                          },
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            backgroundColor:
                                                colors.tertiaryContainer,
                                            foregroundColor:
                                                colors.onTertiaryContainer,
                                          ),
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                            size: 14,
                                          ),
                                          label: const Text(
                                            'Reset',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('no-reset-radius'),
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.rounded_corner_rounded,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 36,
                                    activeTrackColor: colors.primary,
                                    inactiveTrackColor:
                                        colors.surfaceContainerHighest,
                                    thumbColor: colors.primary,
                                    trackShape:
                                        const RoundedRectSliderTrackShape(),
                                  ),
                                  child: Slider(
                                    value: _radius,
                                    min: 0,
                                    max: 60,
                                    onChanged: (value) {
                                      if (value.floor() != _radius.floor()) {
                                        HapticFeedback.selectionClick();
                                      }
                                      setState(() => _radius = value);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 46,
                                child: Text(
                                  '${_radius.floor()} dp',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: fullWidth ? 0 : systemInset,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.linear,
                      width: double.infinity,
                      height: previewHeight,
                      decoration: ShapeDecoration(
                        color: colors.onSurface,
                        shape: _navBarShape(
                          smooth: smooth,
                          topRadius: fullWidth ? _radius : 10,
                          bottomRadius: fullWidth ? 0 : _radius,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ShapeBorder _navBarShape({
    required bool smooth,
    required double topRadius,
    required double bottomRadius,
  }) {
    final borderRadius = BorderRadius.vertical(
      top: Radius.circular(topRadius),
      bottom: Radius.circular(bottomRadius),
    );
    return smooth
        ? RoundedSuperellipseBorder(borderRadius: borderRadius)
        : RoundedRectangleBorder(borderRadius: borderRadius);
  }
}
