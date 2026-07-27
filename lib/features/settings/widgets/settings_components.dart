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

class SettingsSliderItem extends StatelessWidget {
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
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  valueText(value),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ],
        ),
      ),
    );
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
