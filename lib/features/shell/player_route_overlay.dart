import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import '../player/full_player.dart';
import '../player/mini_player.dart';

/// Preserves Kotlin's root-level UnifiedPlayerSheet while Flutter displays a
/// pushed route. Routes that already host their own player overlay are left
/// untouched by [AppShell]; all other detail/settings routes use this wrapper.
class PlayerRouteOverlay extends StatelessWidget {
  const PlayerRouteOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: !controller.fullPlayerVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && controller.fullPlayerVisible) {
          controller.hideFullPlayer();
        }
      },
      child: Stack(
        children: [
          child,
          if (controller.currentSong != null && !controller.fullPlayerVisible)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: MiniPlayer(isNavBarHidden: true),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !controller.fullPlayerVisible,
              child: AnimatedSlide(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: controller.fullPlayerVisible
                    ? Offset.zero
                    : const Offset(0, 1),
                child: TickerMode(
                  enabled: controller.fullPlayerVisible,
                  child: const FullPlayer(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
