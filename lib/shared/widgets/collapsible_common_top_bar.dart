import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Flutter counterpart of PixelPlayer's Compose `CollapsibleCommonTopBar`.
///
/// The expanded title is anchored to the lower-left edge of the header and
/// travels beside the filled back button while the surface container fades in.
class CollapsibleCommonTopBar extends StatelessWidget {
  const CollapsibleCommonTopBar({
    required this.title,
    required this.onBack,
    this.expandedHeight = 180,
    this.maxLines = 1,
    this.subtitle,
    this.actions = const [],
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final double expandedHeight;
  final int maxLines;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: CollapsibleCommonTopBarDelegate(
        title: title,
        onBack: onBack,
        minHeight: MediaQuery.paddingOf(context).top + 64,
        expandedHeight: expandedHeight,
        maxLines: maxLines,
        subtitle: subtitle,
        actions: actions,
      ),
    );
  }
}

class CollapsibleCommonTopBarDelegate extends SliverPersistentHeaderDelegate {
  const CollapsibleCommonTopBarDelegate({
    required this.title,
    required this.onBack,
    required this.minHeight,
    this.expandedHeight = 180,
    this.maxLines = 1,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final VoidCallback onBack;
  final double minHeight;
  final double expandedHeight;
  final int maxLines;
  final String? subtitle;
  final List<Widget> actions;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => expandedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = Theme.of(context).colorScheme;
    final range = maxExtent - minExtent;
    final fraction = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final solidAlpha = (fraction * 2).clamp(0.0, 1.0);
    final titleStart = lerpDouble(20, 68, fraction)!;
    final titleEnd = actions.isEmpty
        ? 24.0
        : lerpDouble(24, 16 + actions.length * 48, fraction)!;
    final expandedContainerHeight = subtitle == null ? 88.0 : 104.0;
    final titleContainerHeight = lerpDouble(
      expandedContainerHeight,
      56,
      fraction,
    )!;
    final titleBottom = lerpDouble(
      0,
      minHeight - MediaQuery.paddingOf(context).top - 60,
      fraction,
    )!;
    final titleSize = lerpDouble(33.6, 22.4, fraction)!;
    final subtitleAlpha = 1 - fraction;

    return ColoredBox(
      color: colors.surfaceContainerHigh.withValues(alpha: solidAlpha),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 12,
            top: MediaQuery.paddingOf(context).top + 4,
            child: IconButton.filled(
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: colors.surfaceContainerLow,
                foregroundColor: colors.onSurface,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
            ),
          ),
          if (actions.isNotEmpty)
            Positioned(
              right: 8,
              top: MediaQuery.paddingOf(context).top + 4,
              child: Row(children: actions),
            ),
          Positioned(
            left: titleStart,
            right: titleEnd,
            bottom: titleBottom,
            height: titleContainerHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colors.onSurface,
                      fontSize: titleSize,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle case final value?)
                    Opacity(
                      opacity: subtitleAlpha,
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant CollapsibleCommonTopBarDelegate oldDelegate) {
    return title != oldDelegate.title ||
        onBack != oldDelegate.onBack ||
        minHeight != oldDelegate.minHeight ||
        expandedHeight != oldDelegate.expandedHeight ||
        maxLines != oldDelegate.maxLines ||
        subtitle != oldDelegate.subtitle ||
        actions != oldDelegate.actions;
  }
}
