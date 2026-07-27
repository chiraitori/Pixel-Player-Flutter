import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _PlaybackButtonType { previous, playPause, next }

class AnimatedPlaybackControls extends StatefulWidget {
  const AnimatedPlaybackControls({
    required this.isPlaying,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.colorPrevious,
    required this.colorPlayPause,
    required this.colorNext,
    required this.tintPrevious,
    required this.tintPlayPause,
    required this.tintNext,
    this.hapticFeedbackEnabled = true,
    this.height = 80,
    super.key,
  });

  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final Color colorPrevious;
  final Color colorPlayPause;
  final Color colorNext;
  final Color tintPrevious;
  final Color tintPlayPause;
  final Color tintNext;
  final bool hapticFeedbackEnabled;
  final double height;

  @override
  State<AnimatedPlaybackControls> createState() =>
      _AnimatedPlaybackControlsState();
}

class _AnimatedPlaybackControlsState extends State<AnimatedPlaybackControls> {
  _PlaybackButtonType? _lastClicked;
  Timer? _releaseTimer;
  bool? _pendingPlayingState;
  late bool _visualPlaying;

  @override
  void initState() {
    super.initState();
    _visualPlaying = widget.isPlaying;
  }

  @override
  void didUpdateWidget(covariant AnimatedPlaybackControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying == widget.isPlaying) return;
    final locked =
        _lastClicked == _PlaybackButtonType.previous ||
        _lastClicked == _PlaybackButtonType.next;
    if (locked) {
      _pendingPlayingState = widget.isPlaying;
    } else {
      _visualPlaying = widget.isPlaying;
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  void _press(_PlaybackButtonType button) {
    setState(() => _lastClicked = button);
    _releaseTimer?.cancel();
    _releaseTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _lastClicked = null;
        if (_pendingPlayingState case final pending?) {
          _visualPlaying = pending;
          _pendingPlayingState = null;
        }
      });
    });

    switch (button) {
      case _PlaybackButtonType.previous:
        widget.onPrevious();
      case _PlaybackButtonType.playPause:
        if (widget.hapticFeedbackEnabled) HapticFeedback.selectionClick();
        widget.onPlayPause();
      case _PlaybackButtonType.next:
        widget.onNext();
    }
  }

  double _weight(_PlaybackButtonType button) {
    if (_lastClicked == null) return 1;
    return _lastClicked == button ? 1.1 : .65;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final available = constraints.maxWidth - gap * 2;
        final previousWeight = _weight(_PlaybackButtonType.previous);
        final playWeight = _weight(_PlaybackButtonType.playPause);
        final nextWeight = _weight(_PlaybackButtonType.next);
        final totalWeight = previousWeight + playWeight + nextWeight;

        return SizedBox(
          height: widget.height,
          child: Row(
            children: [
              _AnimatedTransportButton(
                width: available * previousWeight / totalWeight,
                height: widget.height,
                radius: widget.height / 2,
                color: widget.colorPrevious,
                iconColor: widget.tintPrevious,
                icon: Icons.skip_previous_rounded,
                iconSize: 32,
                label: 'Anterior',
                onTap: () => _press(_PlaybackButtonType.previous),
              ),
              const SizedBox(width: gap),
              _AnimatedTransportButton(
                width: available * playWeight / totalWeight,
                height: widget.height,
                radius: _visualPlaying ? 26 : 60,
                color: widget.colorPlayPause,
                iconColor: widget.tintPlayPause,
                icon: _visualPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                iconSize: 36,
                label: _visualPlaying ? 'Pausar' : 'Reproducir',
                onTap: () => _press(_PlaybackButtonType.playPause),
              ),
              const SizedBox(width: gap),
              _AnimatedTransportButton(
                width: available * nextWeight / totalWeight,
                height: widget.height,
                radius: widget.height / 2,
                color: widget.colorNext,
                iconColor: widget.tintNext,
                icon: Icons.skip_next_rounded,
                iconSize: 32,
                label: 'Siguiente',
                onTap: () => _press(_PlaybackButtonType.next),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedTransportButton extends StatelessWidget {
  const _AnimatedTransportButton({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.onTap,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;
  final Color iconColor;
  final IconData icon;
  final double iconSize;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: iconSize,
                color: iconColor,
                semanticLabel: label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
