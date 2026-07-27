import 'package:flutter/material.dart';

/// Flutter counterpart of Compose `HomeGradientTopBar`.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    required this.isScrolled,
    required this.onOpenBeta,
    required this.onOpenStreaming,
    required this.onOpenChangelog,
    required this.onOpenSettings,
    super.key,
  });

  final bool isScrolled;
  final VoidCallback onOpenBeta;
  final VoidCallback onOpenStreaming;
  final VoidCallback onOpenChangelog;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(width: 16),
          FilledButton.tonal(
            key: const ValueKey('home-beta'),
            onPressed: onOpenBeta,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              backgroundColor: colors.surfaceContainerHigh,
              foregroundColor: colors.onSurface,
              shape: const StadiumBorder(),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'β',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const WidgetSpan(child: SizedBox(width: 8)),
                  TextSpan(
                    text: 'Beta',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _TopBarAction(
            icon: Icons.cloud_rounded,
            tooltip: 'Cloud Streaming',
            onPressed: onOpenStreaming,
          ),
          const SizedBox(width: 6),
          _TopBarAction(
            icon: Icons.receipt_long_rounded,
            tooltip: "What's new",
            onPressed: onOpenChangelog,
          ),
          const SizedBox(width: 6),
          _TopBarAction(
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            onPressed: onOpenSettings,
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton.filled(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(40),
        maximumSize: const Size.square(40),
        padding: EdgeInsets.zero,
        backgroundColor: colors.surfaceContainerHigh,
        foregroundColor: colors.onSurface,
      ),
      icon: Icon(icon, size: 24),
    );
  }
}
