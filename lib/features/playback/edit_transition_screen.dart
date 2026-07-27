import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';

class EditTransitionScreen extends StatefulWidget {
  const EditTransitionScreen({super.key});

  @override
  State<EditTransitionScreen> createState() => _EditTransitionScreenState();
}

class _EditTransitionScreenState extends State<EditTransitionScreen> {
  static const _curves = ['Linear', 'Exp', 'Log', 'S curve'];

  bool _initialized = false;
  bool _crossfade = true;
  bool _customOverride = false;
  double _durationMs = 2000;
  String _fadeOutCurve = 'S curve';
  String _fadeInCurve = 'S curve';
  String _playlistId = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final controller = AppScope.of(context);
    _playlistId = controller.stringSetting('transition_playlist_id', '');
    _customOverride = _playlistId.isNotEmpty
        ? controller.boolSetting('${_playlistPrefix}override', false)
        : false;
    final prefix = _customOverride ? _playlistPrefix : '';
    _crossfade = controller.boolSetting(
      '${prefix}playback_crossfade_enabled',
      controller.boolSetting('playback_crossfade_enabled', true),
    );
    _durationMs = controller.doubleSetting(
      '${prefix}playback_crossfade_duration_ms',
      controller.doubleSetting('playback_crossfade_duration_ms', 2000),
    );
    _fadeOutCurve = controller.stringSetting(
      '${prefix}playback_crossfade_curve_out',
      controller.stringSetting('playback_crossfade_curve_out', 'S curve'),
    );
    _fadeInCurve = controller.stringSetting(
      '${prefix}playback_crossfade_curve_in',
      controller.stringSetting('playback_crossfade_curve_in', 'S curve'),
    );
  }

  String get _playlistPrefix => 'transition_playlist_${_playlistId}_';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final playlistScope = _playlistId.isNotEmpty;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            pinned: true,
            backgroundColor: colors.surface,
            surfaceTintColor: colors.surfaceContainer,
            leading: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: IconButton.filled(
                key: const ValueKey('transition-back'),
                onPressed: () => Navigator.maybePop(context),
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceContainerLow,
                  foregroundColor: colors.onSurface,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              ),
            ),
            leadingWidth: 58,
            title: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                playlistScope
                    ? 'Playlist transition rules'
                    : 'Playback transitions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: IconButton.filledTonal(
                  key: const ValueKey('transition-save'),
                  onPressed: _save,
                  style: IconButton.styleFrom(
                    backgroundColor: colors.tertiaryContainer,
                    foregroundColor: colors.onTertiaryContainer,
                  ),
                  icon: const Icon(Icons.save_rounded),
                  tooltip: 'Save',
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList.list(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    playlistScope
                        ? 'Choose how songs in this playlist blend into one another.'
                        : 'Choose how the current song blends into the next one. These settings become the global default.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _TransitionSummaryCard(
                  playlistScope: playlistScope,
                  followingGlobal: !_customOverride,
                  onOverrideChanged: (value) {
                    setState(() {
                      _customOverride = value;
                      if (!value) _loadGlobalValues();
                    });
                  },
                ),
                const SizedBox(height: 24),
                Divider(color: colors.outlineVariant.withValues(alpha: .5)),
                const SizedBox(height: 24),
                _TransitionModeSection(
                  crossfade: _crossfade,
                  onChanged: (value) => setState(() => _crossfade = value),
                ),
                const SizedBox(height: 24),
                _TransitionDetails(
                  visible: _crossfade,
                  durationMs: _durationMs,
                  fadeOutCurve: _fadeOutCurve,
                  fadeInCurve: _fadeInCurve,
                  curves: _curves,
                  onDurationChanged: (value) =>
                      setState(() => _durationMs = value),
                  onResetDuration: () => setState(() => _durationMs = 2000),
                  onFadeOutChanged: (value) =>
                      setState(() => _fadeOutCurve = value),
                  onFadeInChanged: (value) =>
                      setState(() => _fadeInCurve = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _loadGlobalValues() {
    final controller = AppScope.of(context);
    _crossfade = controller.boolSetting('playback_crossfade_enabled', true);
    _durationMs = controller.doubleSetting(
      'playback_crossfade_duration_ms',
      2000,
    );
    _fadeOutCurve = controller.stringSetting(
      'playback_crossfade_curve_out',
      'S curve',
    );
    _fadeInCurve = controller.stringSetting(
      'playback_crossfade_curve_in',
      'S curve',
    );
  }

  void _save() {
    final controller = AppScope.of(context);
    final prefix = _playlistId.isNotEmpty && _customOverride
        ? _playlistPrefix
        : '';
    if (_playlistId.isNotEmpty) {
      controller.setBoolSetting('${_playlistPrefix}override', _customOverride);
    }
    controller
      ..setBoolSetting('${prefix}playback_crossfade_enabled', _crossfade)
      ..setDoubleSetting('${prefix}playback_crossfade_duration_ms', _durationMs)
      ..setStringSetting('${prefix}playback_crossfade_curve_out', _fadeOutCurve)
      ..setStringSetting('${prefix}playback_crossfade_curve_in', _fadeInCurve);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _playlistId.isNotEmpty && !_customOverride
              ? 'Using global transition settings'
              : 'Transition settings saved',
        ),
      ),
    );
  }
}

class _TransitionSummaryCard extends StatelessWidget {
  const _TransitionSummaryCard({
    required this.playlistScope,
    required this.followingGlobal,
    required this.onOverrideChanged,
  });

  final bool playlistScope;
  final bool followingGlobal;
  final ValueChanged<bool> onOverrideChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('transition-summary-card'),
      elevation: 1,
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.auto_awesome_motion_rounded,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active status',
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: colors.primary),
                      ),
                      Text(
                        !playlistScope
                            ? 'Global default'
                            : followingGlobal
                            ? 'Following global settings'
                            : 'Custom playlist override',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (playlistScope) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Custom override',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Use this rule instead of the global default',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Switch(
                      value: !followingGlobal,
                      onChanged: onOverrideChanged,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransitionModeSection extends StatelessWidget {
  const _TransitionModeSection({
    required this.crossfade,
    required this.onChanged,
  });

  final bool crossfade;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.graphic_eq_rounded, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transition style',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Select gapless playback or a smooth crossfade.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MorphingTransitionToggle(value: crossfade, onChanged: onChanged),
      ],
    );
  }
}

class _MorphingTransitionToggle extends StatelessWidget {
  const _MorphingTransitionToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Container(
      key: const ValueKey('transition-mode-toggle'),
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(99),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            AnimatedAlign(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: constraints.maxWidth / 2,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Row(
              children: [
                _ToggleChoice(
                  label: 'None',
                  selected: !value,
                  onTap: () => onChanged(false),
                ),
                _ToggleChoice(
                  label: 'Crossfade',
                  selected: value,
                  onTap: () => onChanged(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChoice extends StatelessWidget {
  const _ToggleChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? colors.onSecondaryContainer
                    : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransitionDetails extends StatelessWidget {
  const _TransitionDetails({
    required this.visible,
    required this.durationMs,
    required this.fadeOutCurve,
    required this.fadeInCurve,
    required this.curves,
    required this.onDurationChanged,
    required this.onResetDuration,
    required this.onFadeOutChanged,
    required this.onFadeInChanged,
  });

  final bool visible;
  final double durationMs;
  final String fadeOutCurve;
  final String fadeInCurve;
  final List<String> curves;
  final ValueChanged<double> onDurationChanged;
  final VoidCallback onResetDuration;
  final ValueChanged<String> onFadeOutChanged;
  final ValueChanged<String> onFadeInChanged;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: !visible
          ? const SizedBox.shrink(key: ValueKey('transition-details-hidden'))
          : Column(
              key: const ValueKey('transition-details-visible'),
              children: [
                _TransitionDurationCard(
                  durationMs: durationMs,
                  onChanged: onDurationChanged,
                  onReset: onResetDuration,
                ),
                const SizedBox(height: 24),
                _TransitionCurvesSection(
                  curves: curves,
                  fadeOutCurve: fadeOutCurve,
                  fadeInCurve: fadeInCurve,
                  onFadeOutChanged: onFadeOutChanged,
                  onFadeInChanged: onFadeInChanged,
                ),
              ],
            ),
    );
  }
}

class _TransitionDurationCard extends StatelessWidget {
  const _TransitionDurationCard({
    required this.durationMs,
    required this.onChanged,
    required this.onReset,
  });

  final double durationMs;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final seconds = (durationMs / 1000).round();
    return Container(
      key: const ValueKey('transition-duration-card'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duration',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '$seconds seconds of overlap',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: colors.primary),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: onReset,
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceContainerHighest,
                  foregroundColor: colors.onSurfaceVariant,
                ),
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Reset duration',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _CrossfadeVisualizer(durationMs: durationMs),
          const SizedBox(height: 24),
          Slider(
            value: durationMs.clamp(0, 12000),
            min: 0,
            max: 12000,
            divisions: 12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CrossfadeVisualizer extends StatelessWidget {
  const _CrossfadeVisualizer({required this.durationMs});

  final double durationMs;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final factor = (durationMs / 12000).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CURRENT',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.tertiary),
            ),
            Text(
              'NEXT',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.secondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final overlapWidth = constraints.maxWidth * (.1 + factor * .4);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.tertiary.withValues(alpha: .5),
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.secondary.withValues(alpha: .5),
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: overlapWidth,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ColoredBox(
                                color: colors.tertiary.withValues(alpha: .3),
                              ),
                            ),
                            Expanded(
                              child: ColoredBox(
                                color: colors.secondary.withValues(alpha: .3),
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.auto_awesome_motion_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(durationMs / 1000).round()} seconds where both tracks play together',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TransitionCurvesSection extends StatelessWidget {
  const _TransitionCurvesSection({
    required this.curves,
    required this.fadeOutCurve,
    required this.fadeInCurve,
    required this.onFadeOutChanged,
    required this.onFadeInChanged,
  });

  final List<String> curves;
  final String fadeOutCurve;
  final String fadeInCurve;
  final ValueChanged<String> onFadeOutChanged;
  final ValueChanged<String> onFadeInChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Curves',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Shape how each track fades during the overlap.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CurveSelectionCard(
                title: 'Fade out',
                curves: curves,
                selected: fadeOutCurve,
                activeColor: colors.tertiaryContainer,
                activeContentColor: colors.onTertiaryContainer,
                onChanged: onFadeOutChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CurveSelectionCard(
                title: 'Fade in',
                curves: curves,
                selected: fadeInCurve,
                activeColor: colors.secondaryContainer,
                activeContentColor: colors.onSecondaryContainer,
                onChanged: onFadeInChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CurveSelectionCard extends StatelessWidget {
  const _CurveSelectionCard({
    required this.title,
    required this.curves,
    required this.selected,
    required this.activeColor,
    required this.activeContentColor,
    required this.onChanged,
  });

  final String title;
  final List<String> curves;
  final String selected;
  final Color activeColor;
  final Color activeContentColor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Text(title, style: Theme.of(context).textTheme.labelLarge),
            ),
            for (final curve in curves)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: curve == selected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onChanged(curve),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              curve,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: curve == selected
                                        ? activeContentColor
                                        : colors.onSurfaceVariant,
                                    fontWeight: curve == selected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                            ),
                          ),
                          if (curve == selected)
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: activeContentColor,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
