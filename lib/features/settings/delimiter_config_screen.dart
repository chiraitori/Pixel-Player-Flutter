import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import '../../shared/widgets/collapsible_common_top_bar.dart';

class DelimiterConfigScreen extends StatelessWidget {
  const DelimiterConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final delimiters = controller.stringListSetting(
      'artist_character_delimiters',
      AppController.defaultArtistDelimiters,
    );
    return DelimiterEditorScreen(
      title: 'Character delimiters',
      subtitle: 'Split artist tags using individual characters.',
      valueLabel: 'Current delimiters',
      inputLabel: 'Add a character delimiter',
      values: delimiters,
      defaults: AppController.defaultArtistDelimiters,
      minimumCount: 1,
      duplicateCaseInsensitive: false,
      onSave: (values) {
        controller.setStringListSetting('artist_character_delimiters', values);
        controller.setBoolSetting('artist_rescan_required', true);
      },
    );
  }
}

class DelimiterEditorScreen extends StatefulWidget {
  const DelimiterEditorScreen({
    required this.title,
    required this.subtitle,
    required this.valueLabel,
    required this.inputLabel,
    required this.values,
    required this.defaults,
    required this.minimumCount,
    required this.duplicateCaseInsensitive,
    required this.onSave,
    super.key,
  });

  final String title;
  final String subtitle;
  final String valueLabel;
  final String inputLabel;
  final List<String> values;
  final List<String> defaults;
  final int minimumCount;
  final bool duplicateCaseInsensitive;
  final ValueChanged<List<String>> onSave;

  @override
  State<DelimiterEditorScreen> createState() => _DelimiterEditorScreenState();
}

class _DelimiterEditorScreenState extends State<DelimiterEditorScreen> {
  late List<String> _values = List.of(widget.values);
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final value = _input.text.trim();
    final duplicate = widget.duplicateCaseInsensitive
        ? _values.any((item) => item.toLowerCase() == value.toLowerCase())
        : _values.contains(value);
    if (value.isEmpty || duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a delimiter that is not already listed'),
        ),
      );
      return;
    }
    setState(() => _values.add(value));
    widget.onSave(_values);
    _input.clear();
  }

  void _remove(String value) {
    if (_values.length <= widget.minimumCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one delimiter')),
      );
      return;
    }
    setState(() => _values.remove(value));
    widget.onSave(_values);
  }

  Future<void> _reset() async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded),
        title: const Text('Reset delimiters?'),
        content: const Text(
          'Restore the original PixelPlay delimiter defaults.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (reset != true || !mounted) return;
    setState(() => _values = List.of(widget.defaults));
    widget.onSave(_values);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CollapsibleCommonTopBar(
            title: widget.title,
            onBack: () => Navigator.maybePop(context),
            expandedHeight: widget.title.length > 13 ? 200 : 180,
            maxLines: widget.title.length > 13 ? 2 : 1,
            actions: [
              IconButton.filledTonal(
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt_rounded),
                tooltip: 'Reset defaults',
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
            sliver: SliverList.list(
              children: [
                _EditorCard(
                  title: widget.valueLabel,
                  subtitle: widget.subtitle,
                  child: _values.isEmpty
                      ? Text(
                          'No delimiters configured',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final value in _values)
                              InputChip(
                                label: Text(value),
                                selected: true,
                                onDeleted: () => _remove(value),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                _EditorCard(
                  title: widget.inputLabel,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _add(),
                          decoration: InputDecoration(
                            hintText: widget.inputLabel,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: _add,
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'Add delimiter',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _EditorCard(
                  title: 'Default values',
                  subtitle: widget.defaults
                      .map((item) => '"$item"')
                      .join('  •  '),
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle case final value?) ...[
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (child is! SizedBox) const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
