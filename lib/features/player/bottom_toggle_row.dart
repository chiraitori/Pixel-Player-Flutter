import 'package:flutter/material.dart';

class BottomToggleRow extends StatelessWidget {
  const BottomToggleRow({
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.favorite,
    required this.onShuffle,
    required this.onRepeat,
    required this.onFavorite,
    super.key,
  });

  final bool shuffleEnabled;
  final int repeatMode;
  final bool favorite;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final containerBg = colors.surfaceContainer;
    final inactiveBg = colors.surfaceContainerHighest;
    final inactiveIconColor = colors.onSurfaceVariant;

    return Container(
      height: 72,
      padding: const EdgeInsets.all(8),
      decoration: ShapeDecoration(
        color: containerBg,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleSegment(
              active: shuffleEnabled,
              activeColor: colors.primary,
              activeContentColor: colors.onPrimary,
              inactiveColor: inactiveBg,
              inactiveContentColor: inactiveIconColor,
              icon: Icons.shuffle_rounded,
              label: 'Shuffle',
              onTap: onShuffle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ToggleSegment(
              active: repeatMode != 0,
              activeColor: colors.secondary,
              activeContentColor: colors.onSecondary,
              inactiveColor: inactiveBg,
              inactiveContentColor: inactiveIconColor,
              icon: repeatMode == 1
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              label: 'Repeat',
              onTap: onRepeat,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ToggleSegment(
              active: favorite,
              activeColor: colors.tertiary,
              activeContentColor: colors.onTertiary,
              inactiveColor: inactiveBg,
              inactiveContentColor: inactiveIconColor,
              icon: favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: 'Favorite',
              onTap: onFavorite,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.active,
    required this.activeColor,
    required this.activeContentColor,
    required this.inactiveColor,
    required this.inactiveContentColor,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final Color activeColor;
  final Color activeContentColor;
  final Color inactiveColor;
  final Color inactiveContentColor;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      decoration: BoxDecoration(
        color: active ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(active ? 60 : 8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey(icon.hashCode ^ active.hashCode),
                size: 24,
                color: active ? activeContentColor : inactiveContentColor,
                semanticLabel: label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
