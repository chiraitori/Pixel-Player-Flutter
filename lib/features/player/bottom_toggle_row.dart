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
    final inactiveBackground = colors.onSurface.withValues(alpha: .07);
    return Container(
      constraints: const BoxConstraints(minHeight: 52, maxHeight: 86),
      margin: const EdgeInsets.fromLTRB(26, 0, 26, 6),
      padding: const EdgeInsets.all(6),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: colors.surfaceContainerLowest.withValues(alpha: .7),
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(60)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleSegment(
              active: shuffleEnabled,
              activeColor: colors.primaryFixed,
              activeContentColor: colors.onPrimaryFixed,
              inactiveColor: inactiveBackground,
              inactiveContentColor: colors.onSurface,
              icon: Icons.shuffle_rounded,
              label: 'Aleatorio',
              onTap: onShuffle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ToggleSegment(
              active: repeatMode != 0,
              activeColor: colors.secondaryFixed,
              activeContentColor: colors.onSecondaryFixed,
              inactiveColor: inactiveBackground,
              inactiveContentColor: colors.onSurface,
              icon: repeatMode == 1
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              label: 'Repetir',
              onTap: onRepeat,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ToggleSegment(
              active: favorite,
              activeColor: colors.tertiaryFixed,
              activeContentColor: colors.onTertiaryFixed,
              inactiveColor: inactiveBackground,
              inactiveContentColor: colors.onSurface,
              icon: favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: 'Favorito',
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
      curve: Curves.easeOutCubic,
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
                key: ValueKey(icon),
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
