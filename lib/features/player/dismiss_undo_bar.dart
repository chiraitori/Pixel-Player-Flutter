import 'package:flutter/material.dart';

class DismissUndoBar extends StatefulWidget {
  const DismissUndoBar({
    required this.onUndo,
    required this.onClose,
    required this.duration,
    super.key,
  });

  final VoidCallback onUndo;
  final VoidCallback onClose;
  final Duration duration;

  @override
  State<DismissUndoBar> createState() => _DismissUndoBarState();
}

class _DismissUndoBarState extends State<DismissUndoBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    )..reverse();
  }

  @override
  void didUpdateWidget(covariant DismissUndoBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _progress
        ..duration = widget.duration
        ..value = 1
        ..reverse();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      color: colors.surfaceContainerHigh,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 64,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        'Playlist dismissed',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontFamily: 'GoogleSansFlex',
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: widget.onUndo,
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: colors.surfaceContainerLow,
                      foregroundColor: colors.primary,
                      minimumSize: const Size(64, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: const Text(
                      'Undo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: widget.onClose,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surfaceContainerLow,
                      foregroundColor: colors.onSurface.withValues(alpha: .7),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            IgnorePointer(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedBuilder(
                  animation: _progress,
                  builder: (context, child) => FractionallySizedBox(
                    widthFactor: _progress.value.clamp(0, 1),
                    heightFactor: 1,
                    alignment: Alignment.centerLeft,
                    child: child,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(12),
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
