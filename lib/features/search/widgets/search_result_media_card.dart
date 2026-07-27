import 'package:flutter/material.dart';

class SearchResultMediaCard extends StatelessWidget {
  const SearchResultMediaCard({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onOpen,
    required this.onPlay,
    required this.playButtonColor,
    required this.playButtonContentColor,
    this.selected = false,
    this.selectionIndex,
    this.selectionMode = false,
    this.onLongPress,
    this.onSelectionToggle,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;
  final Color playButtonColor;
  final Color playButtonContentColor;
  final bool selected;
  final int? selectionIndex;
  final bool selectionMode;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectionToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(26),
      side: selected
          ? BorderSide(color: colors.primary, width: 2)
          : BorderSide.none,
    );
    return AnimatedScale(
      scale: selected ? .98 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.fastOutSlowIn,
      child: Material(
        color: colors.surfaceContainerLow,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selectionMode ? (onSelectionToggle ?? onOpen) : onOpen,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox.square(dimension: 56, child: leading),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: onPlay,
                      style: IconButton.styleFrom(
                        fixedSize: const Size.square(40),
                        minimumSize: const Size.square(40),
                        maximumSize: const Size.square(40),
                        padding: EdgeInsets.zero,
                        backgroundColor: playButtonColor.withValues(alpha: .8),
                        foregroundColor: playButtonContentColor,
                        disabledBackgroundColor: colors.surfaceContainerHighest,
                        disabledForegroundColor: colors.onSurfaceVariant,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      tooltip: 'Play',
                    ),
                  ],
                ),
              ),
              if (selectionMode && selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      selectionIndex?.toString() ?? '✓',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
