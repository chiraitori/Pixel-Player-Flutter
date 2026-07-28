import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/playing_eq_icon.dart';
import 'sleep_timer_bottom_sheet.dart';
import 'song_info_bottom_sheet.dart';

Future<void> showPlayerQueueBottomSheet(
  BuildContext context, {
  ValueChanged<bool>? onVisibilityChanged,
}) async {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  onVisibilityChanged?.call(true);
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: .42),
      showDragHandle: false,
      sheetAnimationStyle: reduceMotion
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 220),
              reverseDuration: Duration(milliseconds: 180),
            ),
      builder: (_) => const _QueueSheet(),
    );
  } finally {
    onVisibilityChanged?.call(false);
  }
}

class _QueueSheet extends StatefulWidget {
  const _QueueSheet();

  @override
  State<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<_QueueSheet> {
  ScrollController? _scrollController;
  bool _actionsExpanded = false;
  bool _locatedInitialSong = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final currentIndex = controller.queue.indexWhere(
      (song) => song.id == controller.currentSong?.id,
    );
    final showHistory = controller.boolSetting('show_queue_history', false);
    final queueOffset = showHistory || currentIndex < 0 ? 0 : currentIndex;
    final displayQueue = controller.queue.sublist(
      queueOffset.clamp(0, controller.queue.length),
    );
    final currentDisplayIndex = currentIndex < 0
        ? -1
        : currentIndex - queueOffset;

    if (!_locatedInitialSong && currentDisplayIndex > 0) {
      _locatedInitialSong = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final scrollController = _scrollController;
        if (!mounted ||
            scrollController == null ||
            !scrollController.hasClients) {
          return;
        }
        scrollController.jumpTo(currentDisplayIndex * 82.0);
      });
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      minChildSize: .42,
      maxChildSize: 1,
      snap: true,
      snapSizes: const [.42, .92, 1],
      builder: (context, sheetScrollController) {
        _scrollController = sheetScrollController;
        return Material(
          key: const ValueKey('queue-sheet'),
          color: colors.surfaceContainer,
          elevation: 10,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                children: [
                  _QueueHeader(
                    count: displayQueue.length,
                    sourceName: 'Current queue',
                    onLocate: currentDisplayIndex < 0
                        ? null
                        : () => _locateCurrent(currentDisplayIndex),
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(26),
                        ),
                      ),
                      child: displayQueue.isEmpty
                          ? Center(
                              child: Text(
                                'Queue is empty',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            )
                          : ReorderableListView.builder(
                              key: const ValueKey('queue-song-list'),
                              scrollController: sheetScrollController,
                              buildDefaultDragHandles: false,
                              padding: const EdgeInsets.fromLTRB(0, 6, 0, 118),
                              proxyDecorator: (child, index, animation) {
                                return ScaleTransition(
                                  scale: Tween<double>(begin: 1, end: 1.015)
                                      .animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.fastOutSlowIn,
                                        ),
                                      ),
                                  child: Material(
                                    color: Colors.transparent,
                                    elevation: 4,
                                    child: child,
                                  ),
                                );
                              },
                              itemCount: displayQueue.length,
                              onReorderItem: (oldIndex, adjustedNewIndex) {
                                final sourceIndex = queueOffset + oldIndex;
                                final rawNewIndex = adjustedNewIndex > oldIndex
                                    ? adjustedNewIndex + 1
                                    : adjustedNewIndex;
                                final targetIndex = queueOffset + rawNewIndex;
                                if (sourceIndex <= currentIndex) return;
                                controller.reorderQueue(
                                  sourceIndex,
                                  targetIndex,
                                );
                              },
                              itemBuilder: (context, index) {
                                final song = displayQueue[index];
                                final queueIndex = queueOffset + index;
                                final isCurrent = index == currentDisplayIndex;
                                final canReorder =
                                    queueIndex > currentIndex && !isCurrent;
                                return Padding(
                                  key: ValueKey(
                                    'queue-row-${song.id}-$queueIndex',
                                  ),
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _DismissibleQueueRow(
                                    song: song,
                                    index: index,
                                    isCurrent: isCurrent,
                                    canReorder: canReorder,
                                    isPlaying:
                                        isCurrent && controller.isPlaying,
                                    onTap: () => controller.playSong(
                                      song,
                                      fromQueue: controller.queue,
                                    ),
                                    onMore: () =>
                                        _showSongOptions(controller, song),
                                    onRemoved: () =>
                                        _removeSong(controller, song),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: _QueueBottomToolbar(
                    shuffleEnabled: controller.shuffleEnabled,
                    repeatMode: controller.repeatMode,
                    timerActive: controller.sleepTimerLabel != null,
                    actionsExpanded: _actionsExpanded,
                    onShuffle: controller.toggleShuffle,
                    onRepeat: controller.cycleRepeatMode,
                    onTimer: () =>
                        showSleepTimerBottomSheet(context, controller),
                    onMore: () {
                      setState(() => _actionsExpanded = !_actionsExpanded);
                    },
                  ),
                ),
              ),
              if (_actionsExpanded)
                Positioned.fill(
                  child: _QueueActionsOverlay(
                    canLocate: currentDisplayIndex >= 0,
                    onDismiss: () => setState(() => _actionsExpanded = false),
                    onLocate: () {
                      setState(() => _actionsExpanded = false);
                      _locateCurrent(currentDisplayIndex);
                    },
                    onClear: () {
                      setState(() => _actionsExpanded = false);
                      _confirmClearQueue(controller);
                    },
                    onSave: () {
                      setState(() => _actionsExpanded = false);
                      _showSaveQueue(controller);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _locateCurrent(int index) {
    final scrollController = _scrollController;
    if (index < 0 || scrollController == null || !scrollController.hasClients) {
      return;
    }
    scrollController.animateTo(
      (index * 82.0).clamp(0, scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _removeSong(AppController controller, Song song) {
    if (!controller.removeSongFromQueue(song.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${song.title} removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: controller.undoRemoveSongFromQueue,
          ),
        ),
      );
  }

  Future<void> _showSongOptions(AppController controller, Song song) async {
    await showSongInfoBottomSheet(context: context, song: song);
  }

  Future<void> _confirmClearQueue(AppController controller) async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear queue?'),
        content: const Text(
          'Every queued track except the current track will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (clear == true) controller.clearQueueExceptCurrent();
  }

  Future<void> _showSaveQueue(AppController controller) async {
    final name = TextEditingController(text: 'Current queue');
    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save as playlist'),
          content: TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Playlist name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (save != true || name.text.trim().isEmpty) return;
      controller.createPlaylist(
        name.text.trim(),
        controller.queue.map((song) => song.id),
      );
    } finally {
      name.dispose();
    }
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({
    required this.count,
    required this.sourceName,
    required this.onLocate,
  });

  final int count;
  final String sourceName;
  final VoidCallback? onLocate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('queue-header'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Container(
            key: const ValueKey('queue-sheet-handle'),
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: onLocate,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next up',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontFamily: 'GoogleSansRounded',
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count == 0
                            ? 'No tracks lined up'
                            : '$count ${count == 1 ? 'track' : 'tracks'} lined up',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                constraints: const BoxConstraints(maxWidth: 190),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: ShapeDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: .88),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.queue_music_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        sourceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DismissibleQueueRow extends StatelessWidget {
  const _DismissibleQueueRow({
    required this.song,
    required this.index,
    required this.isCurrent,
    required this.canReorder,
    required this.isPlaying,
    required this.onTap,
    required this.onMore,
    required this.onRemoved,
  });

  final Song song;
  final int index;
  final bool isCurrent;
  final bool canReorder;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    final row = _QueueSongRow(
      song: song,
      index: index,
      isCurrent: isCurrent,
      canReorder: canReorder,
      isPlaying: isPlaying,
      onTap: onTap,
      onMore: onMore,
    );
    if (!canReorder) return row;
    return Dismissible(
      key: ValueKey('queue-dismiss-${song.id}-$index'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: .38},
      background: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Icon(
                Icons.close_rounded,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ),
      ),
      onDismissed: (_) => onRemoved(),
      child: row,
    );
  }
}

class _QueueSongRow extends StatelessWidget {
  const _QueueSongRow({
    required this.song,
    required this.index,
    required this.isCurrent,
    required this.canReorder,
    required this.isPlaying,
    required this.onTap,
    required this.onMore,
  });

  final Song song;
  final int index;
  final bool isCurrent;
  final bool canReorder;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = isCurrent ? 60.0 : 22.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        key: ValueKey('queue-song-${song.id}-$index'),
        color: colors.surfaceContainerLowest,
        elevation: 1,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
            child: Row(
              children: [
                if (canReorder)
                  ReorderableDragStartListener(
                    index: index,
                    child: const SizedBox.square(
                      dimension: 40,
                      child: Icon(Icons.drag_indicator_rounded),
                    ),
                  ),
                SizedBox(width: canReorder ? 6 : 12),
                Artwork(
                  colors: song.colors,
                  size: 42,
                  borderRadius: isCurrent ? 21 : 8,
                  iconSize: 17,
                  mediaStoreId: song.mediaStoreId,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isCurrent ? colors.primary : colors.onSurface,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isCurrent
                              ? colors.primary.withValues(alpha: .8)
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  PlayingEqIcon(
                    isPlaying: isPlaying,
                    color: colors.secondary,
                  ),
                  const SizedBox(width: 8),
                ] else
                  const SizedBox(width: 8),
                SizedBox.square(
                  dimension: 40,
                  child: IconButton.filled(
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: isCurrent
                          ? colors.tertiaryContainer
                          : colors.surfaceContainerHigh,
                      foregroundColor: isCurrent
                          ? colors.onTertiaryContainer
                          : colors.onSurface,
                    ),
                    onPressed: onMore,
                    icon: const Icon(Icons.more_vert_rounded, size: 24),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueBottomToolbar extends StatelessWidget {
  const _QueueBottomToolbar({
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.timerActive,
    required this.actionsExpanded,
    required this.onShuffle,
    required this.onRepeat,
    required this.onTimer,
    required this.onMore,
  });

  final bool shuffleEnabled;
  final int repeatMode;
  final bool timerActive;
  final bool actionsExpanded;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final VoidCallback onTimer;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        key: const ValueKey('queue-bottom-toolbar'),
        height: 70,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: colors.surfaceContainerHighest,
              shape: RoundedSuperellipseBorder(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(50),
                  bottomLeft: Radius.circular(50),
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _QueueToolbarButton(
                      active: shuffleEnabled,
                      icon: Icons.shuffle_rounded,
                      label: 'Shuffle',
                      onTap: onShuffle,
                    ),
                    const SizedBox(width: 12),
                    _QueueToolbarButton(
                      active: repeatMode != 0,
                      icon: repeatMode == 1
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      label: 'Repeat',
                      onTap: onRepeat,
                    ),
                    const SizedBox(width: 12),
                    _QueueToolbarButton(
                      active: timerActive,
                      icon: Icons.timer_rounded,
                      label: 'Sleep timer',
                      onTap: onTimer,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox.square(
              dimension: 70,
              child: FloatingActionButton(
                heroTag: null,
                elevation: 0,
                backgroundColor: colors.tertiaryContainer,
                foregroundColor: colors.onTertiaryContainer,
                shape: RoundedSuperellipseBorder(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                    topRight: Radius.circular(50),
                    bottomRight: Radius.circular(50),
                  ),
                ),
                onPressed: onMore,
                child: AnimatedRotation(
                  turns: actionsExpanded ? .125 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.more_horiz_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueToolbarButton extends StatelessWidget {
  const _QueueToolbarButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 48,
      child: IconButton.filled(
        tooltip: label,
        style: IconButton.styleFrom(
          backgroundColor: active ? colors.primary : colors.surfaceContainer,
          foregroundColor: active ? colors.onPrimary : colors.onSurfaceVariant,
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        icon: Icon(icon),
      ),
    );
  }
}

class _QueueActionsOverlay extends StatelessWidget {
  const _QueueActionsOverlay({
    required this.canLocate,
    required this.onDismiss,
    required this.onLocate,
    required this.onClear,
    required this.onSave,
  });

  final bool canLocate;
  final VoidCallback onDismiss;
  final VoidCallback onLocate;
  final VoidCallback onClear;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.scrim.withValues(alpha: .55),
      child: InkWell(
        onTap: onDismiss,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, colors.surfaceContainerLowest],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 106),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canLocate)
                    _QueueActionButton(
                      icon: Icons.my_location_rounded,
                      label: 'Locate current song',
                      background: colors.tertiaryContainer,
                      foreground: colors.onTertiaryContainer,
                      onTap: onLocate,
                    ),
                  if (canLocate) const SizedBox(height: 10),
                  _QueueActionButton(
                    icon: Icons.clear_all_rounded,
                    label: 'Clear queue',
                    background: colors.errorContainer,
                    foreground: colors.onErrorContainer,
                    onTap: onClear,
                  ),
                  const SizedBox(height: 10),
                  _QueueActionButton(
                    icon: Icons.library_add_rounded,
                    label: 'Save as playlist',
                    background: colors.primaryContainer,
                    foreground: colors.onPrimaryContainer,
                    onTap: onSave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueActionButton extends StatelessWidget {
  const _QueueActionButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 184, maxWidth: 260),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
