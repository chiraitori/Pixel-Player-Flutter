import 'package:flutter/material.dart';

class EditTransitionScreen extends StatefulWidget {
  const EditTransitionScreen({super.key});

  @override
  State<EditTransitionScreen> createState() => _EditTransitionScreenState();
}

class _EditTransitionScreenState extends State<EditTransitionScreen> {
  bool crossfade = false;
  bool customOverride = false;
  double duration = 3;
  double fadeOutCurve = .5;
  double fadeInCurve = .5;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.save_rounded),
        label: const Text('Save'),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            pinned: true,
            title: Text('Playback transition'),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList.list(
              children: [
                Card(
                  color: colors.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Choose how the current song blends into the next one. '
                      'These settings become the global default.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    value: customOverride,
                    onChanged: (value) =>
                        setState(() => customOverride = value),
                    secondary: const Icon(Icons.rule_rounded),
                    title: const Text('Custom override'),
                    subtitle: const Text(
                      'Use this rule instead of the global default',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Transition style',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Select gapless playback or a smooth crossfade.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.compare_arrows_rounded),
                      label: Text('None'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.multiline_chart_rounded),
                      label: Text('Crossfade'),
                    ),
                  ],
                  selected: {crossfade},
                  onSelectionChanged: (values) =>
                      setState(() => crossfade = values.first),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duration • ${duration.toStringAsFixed(1)} seconds',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Slider(
                          value: duration,
                          min: .5,
                          max: 12,
                          divisions: 23,
                          onChanged: crossfade
                              ? (value) => setState(() => duration = value)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 86,
                          child: CustomPaint(
                            painter: _TransitionPainter(
                              color: colors.primary,
                              secondary: colors.tertiary,
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('CURRENT'),
                                Spacer(),
                                Text('NEXT'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Curves',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        _CurveControl(
                          label: 'Fade out',
                          value: fadeOutCurve,
                          enabled: crossfade,
                          onChanged: (value) =>
                              setState(() => fadeOutCurve = value),
                        ),
                        _CurveControl(
                          label: 'Fade in',
                          value: fadeInCurve,
                          enabled: crossfade,
                          onChanged: (value) =>
                              setState(() => fadeInCurve = value),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurveControl extends StatelessWidget {
  const _CurveControl({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 74, child: Text(label)),
        Expanded(
          child: Slider(value: value, onChanged: enabled ? onChanged : null),
        ),
        SizedBox(width: 42, child: Text(value.toStringAsFixed(1))),
      ],
    );
  }
}

class _TransitionPainter extends CustomPainter {
  const _TransitionPainter({required this.color, required this.secondary});

  final Color color;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final first = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    final second = Paint()
      ..color = secondary
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, 12), Offset(size.width, size.height - 18), first);
    canvas.drawLine(
      Offset(0, size.height - 18),
      Offset(size.width, 12),
      second,
    );
  }

  @override
  bool shouldRepaint(covariant _TransitionPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.secondary != secondary;
  }
}
