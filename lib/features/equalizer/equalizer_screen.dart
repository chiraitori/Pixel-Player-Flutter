import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  bool enabled = false;
  String preset = 'Flat';
  final bands = <double>[.5, .5, .5, .5, .5];
  double bassBoost = .2;
  double virtualizer = 0;
  double loudness = .35;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final controller = AppScope.of(context);
    enabled = controller.boolSetting('equalizer_enabled', false);
    preset = controller.stringSetting('equalizer_preset', 'Flat');
    final storedBands = controller.equalizerBands;
    for (var index = 0; index < bands.length; index++) {
      bands[index] = ((storedBands[index] + 12) / 24).clamp(0, 1);
    }
    bassBoost = controller.doubleSetting('equalizer_bass_boost', .2);
    virtualizer = controller.doubleSetting('equalizer_virtualizer', 0);
    loudness = controller.doubleSetting('equalizer_loudness', .35);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
          IconButton.filledTonal(
            onPressed: () {
              setState(() {
                bands.fillRange(0, bands.length, .5);
                preset = 'Flat';
                bassBoost = 0;
                virtualizer = 0;
                loudness = 0;
              });
              controller
                ..setStringSetting('equalizer_preset', preset)
                ..setEqualizerBands(_bandGains())
                ..setDoubleSetting('equalizer_bass_boost', 0)
                ..setDoubleSetting('equalizer_virtualizer', 0)
                ..setEqualizerLoudness(0);
            },
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset',
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () {
              setState(() => enabled = !enabled);
              controller.setEqualizerEnabled(enabled);
            },
            icon: Icon(
              enabled
                  ? Icons.power_settings_new_rounded
                  : Icons.power_off_rounded,
            ),
            tooltip: enabled ? 'Disable equalizer' : 'Enable equalizer',
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 44),
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final item in [
                  'Flat',
                  'Rock',
                  'Pop',
                  'Jazz',
                  'Classical',
                  'Custom',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: preset == item,
                      onSelected: (_) => _selectPreset(item, controller),
                      label: Text(item),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit'),
                  onPressed: () => _saveCustomPreset(controller),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Frequency response',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 260,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < bands.length; index++)
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${((bands[index] - .5) * 24).round()} dB',
                                ),
                                Expanded(
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Slider(
                                      value: bands[index],
                                      onChanged: enabled
                                          ? (value) => setState(() {
                                              bands[index] = value;
                                              preset = 'Custom';
                                              controller
                                                ..setStringSetting(
                                                  'equalizer_preset',
                                                  preset,
                                                )
                                                ..setEqualizerBands(
                                                  _bandGains(),
                                                );
                                            })
                                          : null,
                                    ),
                                  ),
                                ),
                                Text(
                                  const [
                                    '60',
                                    '230',
                                    '910',
                                    '3.6k',
                                    '14k',
                                  ][index],
                                ),
                                Text(
                                  'Hz',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _EffectCard(
            title: 'Bass boost',
            icon: Icons.surround_sound_rounded,
            value: bassBoost,
            enabled: enabled,
            color: colors.primaryContainer,
            onChanged: (value) {
              setState(() {
                bassBoost = value;
                bands[0] = (.5 + value * .35).clamp(0, 1);
                bands[1] = (.5 + value * .2).clamp(0, 1);
                preset = 'Custom';
              });
              controller
                ..setDoubleSetting('equalizer_bass_boost', value)
                ..setEqualizerBands(_bandGains());
            },
          ),
          _EffectCard(
            title: 'Virtualizer',
            icon: Icons.spatial_audio_off_rounded,
            value: virtualizer,
            enabled: enabled,
            color: colors.secondaryContainer,
            onChanged: (value) {
              setState(() => virtualizer = value);
              controller.setDoubleSetting('equalizer_virtualizer', value);
            },
          ),
          _EffectCard(
            title: 'Loudness',
            icon: Icons.volume_up_rounded,
            value: loudness,
            enabled: enabled,
            color: colors.tertiaryContainer,
            onChanged: (value) {
              setState(() => loudness = value);
              controller.setEqualizerLoudness(value);
            },
          ),
        ],
      ),
    );
  }

  List<double> _bandGains() =>
      bands.map((value) => (value - .5) * 24).toList(growable: false);

  void _selectPreset(String next, AppController controller) {
    if (next == 'Custom') {
      setState(() => preset = next);
      controller.setStringSetting('equalizer_preset', next);
      return;
    }
    final values = switch (next) {
      'Rock' => <double>[.72, .58, .43, .64, .76],
      'Pop' => <double>[.58, .68, .7, .58, .5],
      'Jazz' => <double>[.67, .55, .55, .65, .72],
      'Classical' => <double>[.68, .56, .48, .62, .75],
      _ => <double>[.5, .5, .5, .5, .5],
    };
    setState(() {
      preset = next;
      for (var index = 0; index < bands.length; index++) {
        bands[index] = values[index];
      }
    });
    controller
      ..setStringSetting('equalizer_preset', next)
      ..setEqualizerBands(_bandGains());
  }

  Future<void> _saveCustomPreset(AppController controller) async {
    final name = TextEditingController(text: preset == 'Custom' ? '' : preset);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save preset'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Preset name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final clean = name.text.trim();
              if (clean.isNotEmpty) {
                controller
                  ..setStringSetting('equalizer_custom_preset_name', clean)
                  ..setStringSetting('equalizer_preset', 'Custom')
                  ..setEqualizerBands(_bandGains());
                setState(() => preset = 'Custom');
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
  }
}

class _EffectCard extends StatelessWidget {
  const _EffectCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.color,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final double value;
  final bool enabled;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text('${(value * 100).round()}%'),
                    ],
                  ),
                  Slider(value: value, onChanged: enabled ? onChanged : null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
