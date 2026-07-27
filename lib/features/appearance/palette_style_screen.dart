import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';

class PaletteStyleScreen extends StatefulWidget {
  const PaletteStyleScreen({super.key});

  @override
  State<PaletteStyleScreen> createState() => _PaletteStyleScreenState();
}

class _PaletteStyleScreenState extends State<PaletteStyleScreen> {
  String selected = 'Tonal spot';
  double accuracy = 4;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final controller = AppScope.of(context);
    selected = controller.stringSetting(
      'appearance_palette_style',
      'Tonal spot',
    );
    accuracy = controller.doubleSetting('appearance_color_accuracy', 4);
  }

  static const palettes = <(String, List<Color>)>[
    ('Tonal spot', [Color(0xFF6750A4), Color(0xFF625B71), Color(0xFF7D5260)]),
    ('Vibrant', [Color(0xFF7E3CF0), Color(0xFFE5438D), Color(0xFFFF7A32)]),
    ('Expressive', [Color(0xFF006C84), Color(0xFF6A5F00), Color(0xFF7B5800)]),
    ('Fidelity', [Color(0xFF984061), Color(0xFF80515D), Color(0xFF745B00)]),
    ('Monochrome', [Color(0xFF333333), Color(0xFF666666), Color(0xFF999999)]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Palette style'),
        actions: [
          FilledButton(
            onPressed: () {
              AppScope.of(context)
                ..setStringSetting('appearance_palette_style', selected)
                ..setDoubleSetting('appearance_color_accuracy', accuracy);
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 42),
        children: [
          Text(
            'Choose how PixelPlay turns artwork colors into a complete Material palette.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          for (final palette in palettes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PaletteCard(
                label: palette.$1,
                colors: palette.$2,
                selected: selected == palette.$1,
                onTap: () => setState(() => selected = palette.$1),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Color accuracy',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Increase fidelity to artwork colors while keeping readable contrast.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Slider(
                    value: accuracy,
                    min: 0,
                    max: 10,
                    divisions: 10,
                    label: accuracy.round().toString(),
                    onChanged: (value) => setState(() => accuracy = value),
                  ),
                  Row(
                    children: [
                      const Text('Current'),
                      const Spacer(),
                      Text(
                        accuracy < 4
                            ? 'Subtle'
                            : accuracy < 8
                            ? 'Balanced'
                            : 'Precise',
                      ),
                      const Spacer(),
                      const Text('More accurate'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              for (final color in colors)
                Container(
                  width: 42,
                  height: 52,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
