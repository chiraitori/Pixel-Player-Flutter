import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';

const _timerChoices = <int>[0, 5, 10, 15, 20, 30, 45, 60];

/// Flutter counterpart of Kotlin's [TimerOptionsBottomSheet].
///
/// The original controls are deliberately slider-based rather than a group of
/// chips: the two independent modes (duration / counted tracks) communicate
/// their state through the enabled treatment, expressive containers and the
/// asymmetric action pair.
Future<void> showSleepTimerBottomSheet(
  BuildContext context,
  AppController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _SleepTimerBottomSheet(controller: controller),
  );
}

class _SleepTimerBottomSheet extends StatefulWidget {
  const _SleepTimerBottomSheet({required this.controller});

  final AppController controller;

  @override
  State<_SleepTimerBottomSheet> createState() => _SleepTimerBottomSheetState();
}

class _SleepTimerBottomSheetState extends State<_SleepTimerBottomSheet> {
  late double _timerIndex;
  late double _trackCount;

  @override
  void initState() {
    super.initState();
    final remaining = widget.controller.sleepTimerEnd?.difference(
      DateTime.now(),
    );
    final minutes = remaining == null || remaining.isNegative
        ? 0
        : remaining.inMinutes;
    final index = _timerChoices.indexOf(minutes);
    _timerIndex = (index < 0 ? 0 : index).toDouble();
    _trackCount = (widget.controller.sleepTracksRemaining ?? 1)
        .clamp(1, 10)
        .toDouble();
  }

  int get _selectedMinutes =>
      _timerChoices[_timerIndex.round().clamp(0, _timerChoices.length - 1)];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final hasDurationTimer = widget.controller.sleepTimerEnd != null;
        final hasTrackCounter = widget.controller.sleepTracksRemaining != null;
        final endOfTrackActive = widget.controller.sleepAtEndOfTrack;
        final timerModeEnabled = !hasTrackCounter;
        final counterModeEnabled = !hasDurationTimer && !endOfTrackActive;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: ShapeDecoration(
                    color: colors.surfaceContainerLowest,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Sleep timer',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: colors.primary),
                  ),
                ),
                const SizedBox(height: 24),
                _TimerSliderCard(
                  label: _selectedMinutes == 0
                      ? 'Timer: Off'
                      : 'Timer: $_selectedMinutes minutes',
                  value: _timerIndex,
                  min: 0,
                  max: (_timerChoices.length - 1).toDouble(),
                  divisions: _timerChoices.length - 1,
                  enabled: timerModeEnabled,
                  onChanged: (value) => setState(() => _timerIndex = value),
                  onChangeEnd: (value) {
                    final minutes =
                        _timerChoices[value.round().clamp(
                          0,
                          _timerChoices.length - 1,
                        )];
                    if (minutes == 0) {
                      widget.controller.cancelSleepTimer();
                    } else {
                      widget.controller.setSleepTimer(
                        Duration(minutes: minutes),
                      );
                    }
                  },
                ),
                const SizedBox(height: 18),
                _TimerSliderCard(
                  label: _trackCount.round() == 1
                      ? 'Play count: 1 time'
                      : 'Play count: ${_trackCount.round()} times',
                  value: _trackCount,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  enabled: counterModeEnabled,
                  onChanged: (value) => setState(() => _trackCount = value),
                  onChangeEnd: (value) {
                    widget.controller.setSleepAfterTracks(value.round());
                  },
                ),
                const SizedBox(height: 18),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.fastOutSlowIn,
                  decoration: ShapeDecoration(
                    color: endOfTrackActive
                        ? colors.tertiary
                        : colors.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        endOfTrackActive ? 18 : 50,
                      ),
                    ),
                  ),
                  child: SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      'End of current track',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: endOfTrackActive
                            ? colors.onTertiary
                            : colors.onSurface,
                      ),
                    ),
                    value: endOfTrackActive,
                    onChanged: timerModeEnabled && !hasDurationTimer
                        ? (enabled) {
                            if (enabled) {
                              widget.controller.setSleepAtEndOfTrack();
                            } else {
                              widget.controller.cancelSleepTimer();
                            }
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 68,
                        child: FilledButton(
                          onPressed: counterModeEnabled
                              ? () => _showCustomDurationPicker(context)
                              : null,
                          style: FilledButton.styleFrom(
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(50),
                                bottomLeft: Radius.circular(50),
                                topRight: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                          ),
                          child: const Text('Custom time'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 68,
                        child: FilledButton(
                          onPressed:
                              hasDurationTimer ||
                                  hasTrackCounter ||
                                  endOfTrackActive
                              ? () {
                                  widget.controller.cancelSleepTimer();
                                  Navigator.pop(context);
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.errorContainer,
                            foregroundColor: colors.onErrorContainer,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                                bottomLeft: Radius.circular(8),
                                topRight: Radius.circular(50),
                                bottomRight: Radius.circular(50),
                              ),
                            ),
                          ),
                          child: const Text('Cancel timer'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCustomDurationPicker(BuildContext context) async {
    var hours = 0;
    var minutes = 15;
    final duration = await showDialog<Duration>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set custom duration'),
          content: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: hours,
                  decoration: const InputDecoration(labelText: 'Hours'),
                  items: List.generate(
                    24,
                    (index) =>
                        DropdownMenuItem(value: index, child: Text('$index')),
                  ),
                  onChanged: (value) =>
                      setDialogState(() => hours = value ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: minutes,
                  decoration: const InputDecoration(labelText: 'Minutes'),
                  items: List.generate(
                    60,
                    (index) =>
                        DropdownMenuItem(value: index, child: Text('$index')),
                  ),
                  onChanged: (value) =>
                      setDialogState(() => minutes = value ?? 0),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: hours == 0 && minutes == 0
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      Duration(hours: hours, minutes: minutes),
                    ),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || duration == null) return;
    widget.controller.setSleepTimer(duration);
    Navigator.of(this.context).pop();
  }
}

class _TimerSliderCard extends StatelessWidget {
  const _TimerSliderCard({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        Container(
          decoration: ShapeDecoration(
            color: colors.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 32),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ),
      ],
    );
  }
}
