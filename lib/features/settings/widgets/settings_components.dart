import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsSubsection extends StatelessWidget {
  const SettingsSubsection({
    required this.title,
    required this.children,
    this.addBottomSpace = true,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final bool addBottomSpace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1) const SizedBox(height: 2),
        ],
        if (addBottomSpace) const SizedBox(height: 10),
      ],
    );
  }
}

class SettingsActionItem extends StatelessWidget {
  const SettingsActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.showChevron = false,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool showChevron;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: Icon(icon, size: 24, color: colors.secondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 24,
                child:
                    trailing ??
                    (showChevron
                        ? Icon(
                            Icons.chevron_right_rounded,
                            color: colors.onSurfaceVariant,
                          )
                        : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSwitchItem extends StatelessWidget {
  const SettingsSwitchItem({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged(!value);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (icon case final icon?) ...[
                Icon(icon, size: 24, color: colors.secondary),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onSurface.withValues(
                          alpha: enabled ? 1 : 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant.withValues(
                          alpha: enabled ? 1 : 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: value,
                onChanged: enabled
                    ? (next) {
                        HapticFeedback.selectionClick();
                        onChanged(next);
                      }
                    : null,
                thumbIcon: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return Icon(
                    selected ? Icons.check_rounded : Icons.close_rounded,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsChoiceItem extends StatelessWidget {
  const SettingsChoiceItem({
    required this.label,
    required this.description,
    required this.options,
    required this.selectedKey,
    required this.onSelected,
    required this.icon,
    super.key,
  });

  final String label;
  final String description;
  final Map<String, String> options;
  final String selectedKey;
  final ValueChanged<String> onSelected;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedLabel = options[selectedKey] ?? selectedKey;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showPicker(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: colors.secondary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          selectedLabel,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = options.entries.elementAt(index);
                    final isSelected = entry.key == selectedKey;
                    final colors = Theme.of(context).colorScheme;
                    return Material(
                      color: isSelected
                          ? colors.primaryContainer
                          : colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        onTap: () => Navigator.pop(context, entry.key),
                        title: Text(entry.value),
                        textColor: isSelected
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: colors.primary,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != selectedKey) onSelected(selected);
  }
}

class SettingsSliderItem extends StatefulWidget {
  const SettingsSliderItem({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueText,
    required this.onChanged,
    this.onChangeEnd,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value) valueText;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<SettingsSliderItem> createState() => _SettingsSliderItemState();
}

class _SettingsSliderItemState extends State<SettingsSliderItem> {
  int _lastStepIndex = -1;

  void _handleChanged(double newValue) {
    if (widget.divisions > 0) {
      final stepSpan = (widget.max - widget.min) / widget.divisions;
      final stepIndex = stepSpan > 0 ? ((newValue - widget.min) / stepSpan).round() : 0;
      if (stepIndex != _lastStepIndex) {
        _lastStepIndex = stepIndex;
        HapticFeedback.selectionClick();
      }
    }
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.valueText(widget.value),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 22,
                activeTrackColor: colors.primary,
                inactiveTrackColor: colors.surfaceContainerHigh,
                thumbColor: colors.primaryContainer,
                overlayShape: SliderComponentShape.noOverlay,
                trackShape: _M3ExpressiveSettingsSliderTrackShape(
                  divisions: widget.divisions,
                ),
                thumbShape: _M3ExpressiveSettingsSliderThumbShape(
                  activeColor: colors.onPrimaryContainer,
                ),
              ),
              child: Slider(
                value: widget.value.clamp(widget.min, widget.max),
                min: widget.min,
                max: widget.max,
                divisions: widget.divisions > 0 ? widget.divisions : null,
                onChanged: _handleChanged,
                onChangeEnd: widget.onChangeEnd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _M3ExpressiveSettingsSliderTrackShape extends SliderTrackShape {
  const _M3ExpressiveSettingsSliderTrackShape({required this.divisions});

  final int divisions;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 22.0;
    final trackLeft = offset.dx + 4;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width - 8;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final canvas = context.canvas;
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final trackRadius = Radius.circular(trackRect.height / 2);

    // Inactive Track
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.grey.withValues(alpha: 0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, trackRadius),
      inactivePaint,
    );

    // Active Track
    final activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx.clamp(trackRect.left, trackRect.right),
      trackRect.bottom,
    );
    final activePaint = Paint()..color = sliderTheme.activeTrackColor ?? Colors.blue;
    canvas.drawRRect(
      RRect.fromRectAndRadius(activeRect, trackRadius),
      activePaint,
    );

    // Step Dots
    if (divisions > 1) {
      final activeDotPaint = Paint()
        ..color = (sliderTheme.activeTrackColor ?? Colors.blue).withValues(alpha: 0.35);
      final inactiveDotPaint = Paint()
        ..color = (sliderTheme.activeTrackColor ?? Colors.blue).withValues(alpha: 0.7);

      final stepWidth = trackRect.width / divisions;
      for (int i = 0; i <= divisions; i++) {
        final dotX = trackRect.left + i * stepWidth;
        final dotCenter = Offset(dotX, trackRect.center.dy);
        final isActive = dotX <= thumbCenter.dx + 2;

        canvas.drawCircle(
          dotCenter,
          2.0,
          isActive ? activeDotPaint : inactiveDotPaint,
        );
      }
    }
  }
}

class _M3ExpressiveSettingsSliderThumbShape extends SliderComponentShape {
  const _M3ExpressiveSettingsSliderThumbShape({required this.activeColor});

  final Color activeColor;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(20, 36);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final thumbWidth = 20.0;
    final thumbHeight = 36.0;
    final rect = Rect.fromCenter(
      center: center,
      width: thumbWidth,
      height: thumbHeight,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    // Draw Thumb (Pill)
    final thumbColor = sliderTheme.thumbColor ?? Colors.white;
    canvas.drawRRect(rrect, Paint()..color = thumbColor);

    // Draw 3 small dots inside thumb (...)
    final dotPaint = Paint()..color = activeColor;
    for (int i = -1; i <= 1; i++) {
      canvas.drawCircle(
        Offset(center.dx, center.dy + (i * 6.0)),
        1.5,
        dotPaint,
      );
    }
  }
}

class RefreshLibraryItem extends StatelessWidget {
  const RefreshLibraryItem({
    required this.isSyncing,
    required this.onFullRescan,
    required this.onRebuild,
    super.key,
  });

  final bool isSyncing;
  final Future<void> Function() onFullRescan;
  final Future<void> Function() onRebuild;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.sync_rounded, color: colors.secondary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refresh Library',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Rescan songs and update the music database.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: isSyncing ? null : onFullRescan,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Full Rescan'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isSyncing ? null : onRebuild,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                ),
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('Rebuild Database'),
              ),
            ),
            if (isSyncing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Reading and processing tracks\u2026',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
