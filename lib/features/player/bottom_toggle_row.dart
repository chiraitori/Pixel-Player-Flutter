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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final colors = Theme.of(context).colorScheme;
    // FullPlayerContent.kt uses its private expressive toggle-row palette,
    // rather than the similarly named reusable BottomToggleRow.kt defaults.
    final containerBg = colors.surfaceContainerLowest.withValues(alpha: .7);
    final inactiveBg = colors.onSurface.withValues(alpha: .07);
    final inactiveIconColor = colors.onSurface;

    return Container(
      key: const ValueKey('player-toggle-container'),
      height: 72,
      decoration: ShapeDecoration(
        color: containerBg,
        shape: const StadiumBorder(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ClipPath(
          clipper: const ShapeBorderClipper(shape: StadiumBorder()),
          child: Row(
            children: [
              Expanded(
                child: _ToggleSegment(
                  key: const ValueKey('player-toggle-shuffle'),
                  active: shuffleEnabled,
                  activeColor: colors.primaryFixed,
                  activeContentColor: colors.onPrimaryFixed,
                  inactiveColor: inactiveBg,
                  inactiveContentColor: inactiveIconColor,
                  icon: Icons.shuffle_rounded,
                  label: 'Shuffle',
                  reduceMotion: reduceMotion,
                  onTap: onShuffle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ToggleSegment(
                  key: const ValueKey('player-toggle-repeat'),
                  active: repeatMode != 0,
                  activeColor: colors.secondaryFixed,
                  activeContentColor: colors.onSecondaryFixed,
                  inactiveColor: inactiveBg,
                  inactiveContentColor: inactiveIconColor,
                  icon: repeatMode == 1
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  label: 'Repeat',
                  reduceMotion: reduceMotion,
                  onTap: onRepeat,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ToggleSegment(
                  key: const ValueKey('player-toggle-favorite'),
                  active: favorite,
                  activeColor: colors.tertiaryFixed,
                  activeContentColor: colors.onTertiaryFixed,
                  inactiveColor: inactiveBg,
                  inactiveContentColor: inactiveIconColor,
                  icon: favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: 'Favorite',
                  reduceMotion: reduceMotion,
                  onTap: onFavorite,
                ),
              ),
            ],
          ),
        ),
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
    required this.reduceMotion,
    required this.onTap,
    super.key,
  });

  final bool active;
  final Color activeColor;
  final Color activeContentColor;
  final Color inactiveColor;
  final Color inactiveContentColor;
  final IconData icon;
  final String label;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 250),
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
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
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
