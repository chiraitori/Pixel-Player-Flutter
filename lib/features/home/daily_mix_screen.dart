import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/rounded_star_clipper.dart';
import '../player/full_player.dart';
import '../player/mini_player.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/m3_expressive_loading_indicator.dart';
import '../../shared/widgets/song_tile.dart';

class DailyMixScreen extends StatelessWidget {
  const DailyMixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final songs = controller.dailyMixSongs;
    final colors = Theme.of(context).colorScheme;
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
    final miniVisible = controller.currentSong != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: !controller.fullPlayerVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && controller.fullPlayerVisible) {
          controller.hideFullPlayer();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.primary.withValues(alpha: .25),
                    colors.surface.withValues(alpha: .5),
                    colors.surface,
                  ],
                  stops: const [0, .5, 1],
                ),
              ),
              child: songs.isEmpty
                  ? controller.libraryLoading
                        ? const Center(
                            child: M3ExpressiveLoadingIndicator(
                              contained: true,
                            ),
                          )
                        : const _DailyMixEmptyState()
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _DailyMixHeader(
                            songs: songs,
                            onShowMenu: () =>
                                _showMenu(context, controller, songs),
                          ),
                        ),
                        if (controller.dailyMixGenerating ||
                            controller.dailyMixAiStatus != null ||
                            controller.dailyMixAiError != null)
                          SliverToBoxAdapter(
                            child: _AiMixStatus(controller: controller),
                          ),
                        SliverToBoxAdapter(child: _PlayButtons(songs: songs)),
                        SliverList.builder(
                          itemCount: songs.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SongTile(song: songs[index], queue: songs),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height:
                                systemBottom +
                                (miniVisible
                                    ? miniPlayerHeight + miniPlayerBottomSpacer
                                    : 0) +
                                24,
                          ),
                        ),
                      ],
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 50,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.surfaceContainerLowest.withValues(alpha: .5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        colors.surfaceContainerLowest.withValues(alpha: .5),
                        colors.surfaceContainerLowest,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: MediaQuery.paddingOf(context).top + 8,
              child: IconButton.filled(
                key: const ValueKey('daily-mix-back'),
                onPressed: () => Navigator.maybePop(context),
                style: IconButton.styleFrom(
                  backgroundColor: colors.surface,
                  foregroundColor: colors.onSurface,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              ),
            ),
            if (miniVisible && !controller.fullPlayerVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: systemBottom,
                child: const MiniPlayer(key: ValueKey('daily-mix-mini-player')),
              ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !controller.fullPlayerVisible,
                child: AnimatedSlide(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: controller.fullPlayerVisible
                      ? Offset.zero
                      : const Offset(0, 1),
                  child: TickerMode(
                    enabled: controller.fullPlayerVisible,
                    child: const FullPlayer(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMenu(
    BuildContext context,
    AppController controller,
    List<Song> songs,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: const Text('Create with AI'),
                subtitle: const Text('Describe the mix you want'),
                onTap: () {
                  Navigator.pop(context);
                  _showAiPrompt(context, controller);
                },
              ),
              if (controller.dailyMixAiStatus != null ||
                  controller.dailyMixAiError != null)
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('Reset Daily Mix'),
                  onTap: () {
                    controller.resetDailyMixPrompt();
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Save Daily Mix as playlist'),
                onTap: () {
                  final now = DateTime.now();
                  final date =
                      '${now.year}-${now.month.toString().padLeft(2, '0')}-'
                      '${now.day.toString().padLeft(2, '0')}';
                  controller.createPlaylist(
                    'Daily Mix $date',
                    songs.map((song) => song.id),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Daily Mix saved')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.shuffle_rounded),
                title: const Text('Play shuffled'),
                onTap: () {
                  controller.playShuffled(songs);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAiPrompt(
    BuildContext context,
    AppController controller,
  ) async {
    final prompt = TextEditingController();
    final request = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Create your Daily Mix',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tell Gemini what you want to hear. It only selects songs that '
              'already exist in your library.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: prompt,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Describe your mix',
                hintText:
                    'Dreamy late-night songs, mostly electronic, not too slow…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, prompt.text),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Generate'),
              ),
            ),
          ],
        ),
      ),
    );
    prompt.dispose();
    if (request == null || request.trim().isEmpty || !context.mounted) return;
    if (controller.stringSetting('gemini_api_key', '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your Gemini API key in Settings → AI first'),
        ),
      );
      return;
    }
    await controller.regenerateDailyMixWithPrompt(request);
  }
}

class _AiMixStatus extends StatelessWidget {
  const _AiMixStatus({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final error = controller.dailyMixAiError;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: error == null
            ? colors.secondaryContainer
            : colors.errorContainer,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              if (controller.dailyMixGenerating)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                Icon(
                  error == null
                      ? Icons.auto_awesome_rounded
                      : Icons.error_outline_rounded,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error ?? controller.dailyMixAiStatus ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyMixHeader extends StatelessWidget {
  const _DailyMixHeader({required this.songs, required this.onShowMenu});

  final List<Song> songs;
  final VoidCallback onShowMenu;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final distinct = <Song>[];
    final albumIds = <int?>{};
    for (final song in songs) {
      if (albumIds.add(song.albumId)) distinct.add(song);
      if (distinct.length == 3) break;
    }
    final duration = songs.fold<Duration>(
      Duration.zero,
      (total, song) => total + song.duration,
    );
    return SizedBox(
      key: const ValueKey('daily-mix-header'),
      height: 340,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerX = constraints.maxWidth / 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < distinct.length; index++)
                Positioned(
                  left:
                      centerX +
                      const [-100.0, 0.0, 100.0][index] -
                      const [180.0, 220.0, 180.0][index] / 2,
                  top: (245 - const [180.0, 220.0, 180.0][index]) / 2 + 8,
                  child: Transform.rotate(
                    angle: const [-.261799, 0.0, .261799][index],
                    child: _DailyMixArtworkShape(
                      index: index,
                      song: distinct[index],
                      size: const [180.0, 220.0, 180.0][index],
                    ),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.surface.withValues(alpha: .1),
                        Colors.transparent,
                        colors.surface.withValues(alpha: .5),
                        colors.surface.withValues(alpha: .9),
                        colors.surface,
                      ],
                      stops: const [0, .2, .55, .78, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 22,
                right: 22,
                bottom: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Daily Mix',
                              style: const TextStyle(
                                fontFamily: 'GoogleSansFlex',
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 3),
                              child: Text(
                                '${songs.length} songs • ${_formatMixDuration(duration)}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colors.onSurface.withValues(
                                        alpha: .8,
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _DailyMixAiButton(onPressed: onShowMenu),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DailyMixArtworkShape extends StatelessWidget {
  const _DailyMixArtworkShape({
    required this.index,
    required this.song,
    required this.size,
  });

  final int index;
  final Song song;
  final double size;

  @override
  Widget build(BuildContext context) {
    final artwork = Artwork(
      colors: song.colors,
      size: size,
      borderRadius: 0,
      mediaStoreId: song.mediaStoreId,
    );
    return SizedBox.square(
      dimension: size,
      child: switch (index) {
        0 => ClipPath(
          clipper: const RoundedStarClipper(sides: 6, curve: .05, rotation: 10),
          child: artwork,
        ),
        1 => ClipOval(child: artwork),
        _ => ClipRRect(borderRadius: BorderRadius.circular(30), child: artwork),
      },
    );
  }
}

class _DailyMixAiButton extends StatelessWidget {
  const _DailyMixAiButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'AI playlist generator',
      child: ClipPath(
        clipper: const RoundedStarClipper(sides: 8, curve: .05),
        child: Material(
          color: colors.primaryContainer,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 96,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatMixDuration(Duration duration) {
  if (duration.inHours > 0) {
    return '${duration.inHours} hr ${duration.inMinutes.remainder(60)} min';
  }
  return '${duration.inMinutes} min';
}

class _DailyMixEmptyState extends StatelessWidget {
  const _DailyMixEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 72,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Your Daily Mix is waiting for music',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add songs to your library, then PixelPlay will build a mix for you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButtons extends StatelessWidget {
  const _PlayButtons({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return SizedBox(
      height: 76,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    controller.playSong(songs.first, fromQueue: songs),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(60),
                      bottomLeft: Radius.circular(60),
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play it'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => controller.playShuffled(songs),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      topRight: Radius.circular(60),
                      bottomRight: Radius.circular(60),
                    ),
                  ),
                ),
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('Shuffle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
