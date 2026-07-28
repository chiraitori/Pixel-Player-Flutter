import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import '../player/mini_player.dart';

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
  late final ScrollController _scrollController;
  double _collapseFraction = 0;
  _EqualizerViewMode _viewMode = _EqualizerViewMode.sliders;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_updateCollapse);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateCollapse)
      ..dispose();
    super.dispose();
  }

  void _updateCollapse() {
    if (!_scrollController.hasClients) return;
    // EqualizerScreen.kt collapses the 180dp header to its 64dp minimum.
    final next = (_scrollController.offset / 116).clamp(0.0, 1.0);
    if ((next - _collapseFraction).abs() > .001 && mounted) {
      setState(() => _collapseFraction = next);
    }
  }

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
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const maxHeaderHeight = 180.0;
    final minHeaderHeight = 64 + topInset;
    final headerHeight = ui.lerpDouble(
      maxHeaderHeight,
      minHeaderHeight,
      _collapseFraction,
    )!;
    final contentBottomPadding =
        miniPlayerHeight + miniPlayerBottomSpacer + bottomInset + 20;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              maxHeaderHeight + 8,
              16,
              contentBottomPadding,
            ),
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
                      if (_viewMode != _EqualizerViewMode.sliders) ...[
                        _EqualizerResponseGraph(
                          bands: bands,
                          enabled: enabled,
                          height: _viewMode == _EqualizerViewMode.graph
                              ? 220
                              : 104,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_viewMode != _EqualizerViewMode.graph)
                        SizedBox(
                          height: _viewMode == _EqualizerViewMode.hybrid
                              ? 168
                              : 260,
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
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
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
          _EqualizerTopBar(
            collapseFraction: _collapseFraction,
            headerHeight: headerHeight,
            topInset: topInset,
            enabled: enabled,
            viewMode: _viewMode,
            onBack: () => Navigator.maybePop(context),
            onCycleViewMode: () => setState(() {
              _viewMode =
                  _EqualizerViewMode.values[(_viewMode.index + 1) %
                      _EqualizerViewMode.values.length];
            }),
            onPowerChanged: () {
              setState(() => enabled = !enabled);
              controller.setEqualizerEnabled(enabled);
            },
          ),
          if (controller.currentSong != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: const MiniPlayer(isNavBarHidden: true),
              ),
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

/// The source uses [CollapsibleCommonTopBar]: 180dp when expanded and a 64dp
/// action row when collapsed.  Keeping the calculations here mirrors that
/// Compose component instead of falling back to Flutter's stock [AppBar].
enum _EqualizerViewMode { sliders, graph, hybrid }

class _EqualizerTopBar extends StatelessWidget {
  const _EqualizerTopBar({
    required this.collapseFraction,
    required this.headerHeight,
    required this.topInset,
    required this.enabled,
    required this.viewMode,
    required this.onBack,
    required this.onCycleViewMode,
    required this.onPowerChanged,
  });

  final double collapseFraction;
  final double headerHeight;
  final double topInset;
  final bool enabled;
  final _EqualizerViewMode viewMode;
  final VoidCallback onBack;
  final VoidCallback onCycleViewMode;
  final VoidCallback onPowerChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final solidAlpha = (collapseFraction * 2).clamp(0.0, 1.0);
    final titleLeft = ui.lerpDouble(20, 72, collapseFraction)!;
    final titleTop = ui.lerpDouble(
      topInset + 76,
      topInset + 12,
      collapseFraction,
    )!;
    final titleSize = ui.lerpDouble(28, 22, collapseFraction)!;
    final titleWeight = collapseFraction > .5
        ? FontWeight.w600
        : FontWeight.w500;

    return SizedBox(
      key: const ValueKey('equalizer-collapsible-header'),
      height: headerHeight,
      child: Material(
        color: colors.surfaceContainerHigh.withValues(alpha: solidAlpha),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: titleLeft,
              top: titleTop,
              right: 124,
              child: Text(
                'Equalizer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: titleSize,
                  fontWeight: titleWeight,
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: topInset + 4,
              child: IconButton.filledTonal(
                key: const ValueKey('equalizer-back-button'),
                onPressed: onBack,
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceContainerLow,
                  foregroundColor: colors.onSurface,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              ),
            ),
            Positioned(
              right: 12,
              top: topInset + 4,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    key: const ValueKey('equalizer-view-mode-button'),
                    onPressed: onCycleViewMode,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surfaceContainerLow,
                      foregroundColor: colors.onSurface,
                    ),
                    icon: Icon(switch (viewMode) {
                      _EqualizerViewMode.sliders => Icons.graphic_eq_rounded,
                      _EqualizerViewMode.graph => Icons.show_chart_rounded,
                      _EqualizerViewMode.hybrid => Icons.view_quilt_rounded,
                    }),
                    tooltip: 'Change view mode',
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.fastOutSlowIn,
                    decoration: ShapeDecoration(
                      color: enabled
                          ? colors.primary
                          : colors.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(enabled ? 50 : 12),
                      ),
                    ),
                    child: IconButton(
                      key: const ValueKey('equalizer-power-button'),
                      onPressed: onPowerChanged,
                      color: enabled ? colors.onPrimary : colors.onSurface,
                      icon: const Icon(Icons.power_settings_new_rounded),
                      tooltip: enabled
                          ? 'Disable equalizer'
                          : 'Enable equalizer',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Equivalent to the graph part of Kotlin's BandSlidersSection. The points are
/// the same five Android equalizer bands and animate through [CustomPaint]'s
/// normal repaint path whenever a vertical slider changes.
class _EqualizerResponseGraph extends StatelessWidget {
  const _EqualizerResponseGraph({
    required this.bands,
    required this.enabled,
    required this.height,
  });

  final List<double> bands;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        key: const ValueKey('equalizer-response-graph'),
        painter: _EqualizerResponsePainter(
          bands: List<double>.of(bands),
          lineColor: enabled ? colors.primary : colors.outlineVariant,
          fillColor: (enabled ? colors.primary : colors.outlineVariant)
              .withValues(alpha: .16),
          gridColor: colors.outlineVariant.withValues(alpha: .36),
        ),
      ),
    );
  }
}

class _EqualizerResponsePainter extends CustomPainter {
  const _EqualizerResponsePainter({
    required this.bands,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  final List<double> bands;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 8.0;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var step = 0; step <= 4; step++) {
      final y = size.height * step / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final points = <Offset>[];
    for (var index = 0; index < bands.length; index++) {
      final x =
          horizontalPadding +
          (size.width - horizontalPadding * 2) * index / (bands.length - 1);
      final y = size.height - bands[index] * size.height;
      points.add(Offset(x, y));
    }
    if (points.isEmpty) return;
    path.moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final midpoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        midpoint.dx,
        midpoint.dy,
      );
    }
    path.lineTo(points.last.dx, points.last.dy);

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    for (final point in points) {
      canvas.drawCircle(point, 5, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerResponsePainter oldDelegate) =>
      oldDelegate.bands != bands ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.gridColor != gridColor;
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
