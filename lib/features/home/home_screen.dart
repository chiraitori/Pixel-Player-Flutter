import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/m3_expressive_loading_indicator.dart';
import '../player/mini_player.dart';
import '../shell/player_internal_navigation_bar.dart';
import 'widgets/album_art_collage.dart';
import 'widgets/beta_info_sheet.dart';
import 'widgets/changelog_sheet.dart';
import 'widgets/daily_mix_section.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/recently_played_section.dart';
import 'widgets/stats_overview_card.dart';
import 'widgets/streaming_provider_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.onOpenSettings,
    required this.onOpenDailyMix,
    required this.onOpenRecentlyPlayed,
    required this.onOpenStats,
    required this.onOpenAlbum,
    required this.onOpenAccounts,
    super.key,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenDailyMix;
  final VoidCallback onOpenRecentlyPlayed;
  final VoidCallback onOpenStats;
  final ValueChanged<String> onOpenAlbum;
  final VoidCallback onOpenAccounts;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ScrollController _scrollController;
  bool _scrolledPastThreshold = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final next = _scrollController.hasClients && _scrollController.offset > 180;
    if (next != _scrolledPastThreshold && mounted) {
      setState(() => _scrolledPastThreshold = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final yourMixSongs = controller.yourMixSongs;
    final dailyMixSongs = controller.dailyMixSongs;
    final recentSongs = controller.recentlyPlayedSongs;
    final weekStats = controller.statsFor(
      DateTime.now().subtract(const Duration(days: 7)),
    );
    final systemInset = sanitizeNavigationBarBottomInset(
      MediaQuery.viewPaddingOf(context).bottom,
    );
    final bottomContentPadding =
        resolveNavBarOccupiedHeight(
          systemInset: systemInset,
          compactMode: controller.navBarCompactMode,
        ) +
        38 +
        (controller.currentSong == null ? 0 : miniPlayerHeight);
    final bottomGradientHeight =
        resolveNavBarContentHeight(controller.navBarCompactMode) +
        miniPlayerHeight +
        miniPlayerBottomSpacer +
        8;
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        CustomScrollView(
          key: const PageStorageKey('home-scroll'),
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              key: const ValueKey('home-top-bar'),
              toolbarHeight: 64,
              floating: false,
              pinned: true,
              snap: false,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.transparent,
              automaticallyImplyLeading: false,
              flexibleSpace: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: colors.surfaceContainerHighest.withValues(
                  alpha: _scrolledPastThreshold ? 1 : 0,
                ),
              ),
              titleSpacing: 0,
              title: SizedBox(
                width: MediaQuery.sizeOf(context).width,
                child: HomeTopBar(
                  isScrolled: _scrolledPastThreshold,
                  onOpenBeta: () => _showBetaInfo(context),
                  onOpenStreaming: () => _showStreamingServices(context),
                  onOpenChangelog: () => _showChangelog(context),
                  onOpenSettings: widget.onOpenSettings,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(bottom: bottomContentPadding),
              sliver: SliverList.list(
                children: [
                  if (controller.libraryLoading)
                    const _YourMixLoadingPlaceholder()
                  else if (yourMixSongs.isEmpty)
                    _YourMixEmptyPlaceholder(
                      onRefresh: controller.refreshLibrary,
                    )
                  else ...[
                    _YourMixHeader(
                      key: const ValueKey('home-your-mix-header'),
                      shuffleEnabled: controller.shuffleEnabled,
                      onPlay: () => controller.playShuffled(yourMixSongs),
                    ),
                    const SizedBox(height: 24),
                    AlbumArtCollage(
                      key: const ValueKey('home-album-art-collage'),
                      songs: yourMixSongs,
                      // `HomeScreen.kt` supplies this inset explicitly while
                      // the reusable Compose component itself defaults to 0.
                      padding: 14,
                      pattern: CollagePattern.fromStorageKey(
                        controller.stringSetting(
                          'collage_pattern',
                          CollagePattern.cosmicSwirl.storageKey,
                        ),
                      ),
                      autoRotate: controller.boolSetting(
                        'collage_auto_rotate',
                        false,
                      ),
                      onSongTap: (song) =>
                          controller.playSong(song, fromQueue: yourMixSongs),
                    ),
                  ],
                  if (dailyMixSongs.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    DailyMixSection(
                      key: const ValueKey('home-daily-mix-section'),
                      songs: dailyMixSongs,
                      onOpen: widget.onOpenDailyMix,
                    ),
                  ],
                  if (recentSongs.length >= 4) ...[
                    const SizedBox(height: 24),
                    RecentlyPlayedSection(
                      key: const ValueKey('home-recently-played-section'),
                      songs: recentSongs,
                      onOpenAll: widget.onOpenRecentlyPlayed,
                    ),
                  ],
                  const SizedBox(height: 24),
                  StatsOverviewCard(
                    key: const ValueKey('home-stats-overview'),
                    snapshot: weekStats,
                    songs: controller.songs,
                    onTap: widget.onOpenStats,
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: bottomGradientHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, .2, .8, 1],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    colors.surfaceContainerLowest,
                    colors.surfaceContainerLowest,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showBetaInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) =>
          const FractionallySizedBox(heightFactor: .94, child: BetaInfoSheet()),
    );
  }

  void _showChangelog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const FractionallySizedBox(
        heightFactor: .94,
        child: ChangelogSheet(),
      ),
    );
  }

  void _showStreamingServices(BuildContext context) {
    showStreamingProviderSheet(
      context: context,
      onOpenAccounts: widget.onOpenAccounts,
    );
  }
}

class _YourMixLoadingPlaceholder extends StatelessWidget {
  const _YourMixLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 224,
        child: Center(
          child: M3ExpressiveLoadingIndicator(
            contained: false,
            size: 128,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _YourMixEmptyPlaceholder extends StatelessWidget {
  const _YourMixEmptyPlaceholder({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 256),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: ShapeDecoration(
                color: colors.secondaryContainer,
                shape: const RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.music_note_rounded,
                size: 34,
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your music will appear here',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Add music to this device, then refresh your library.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRefresh,
              style: FilledButton.styleFrom(
                shape: const RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.all(Radius.circular(22)),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _YourMixHeader extends StatelessWidget {
  const _YourMixHeader({
    required this.shuffleEnabled,
    required this.onPlay,
    super.key,
  });

  final bool shuffleEnabled;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 256,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Positioned(
              top: 55,
              left: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your\nMix',
                    style: TextStyle(
                      fontFamily: 'GoogleSansFlex',
                      fontSize: 64,
                      height: 62 / 64,
                      fontWeight: FontWeight.normal,
                      fontVariations: const [
                        ui.FontVariation('wght', 636),
                        // Kotlin's `rememberYourMixTitleStyle` deliberately
                        // uses the wide Google Sans Flex axis (152).  The
                        // previous 87 value condensed the hero headline and
                        // was the source of the visibly squashed "Your Mix"
                        // treatment on Flutter.
                        ui.FontVariation('wdth', 152),
                        ui.FontVariation('ROND', 50),
                        ui.FontVariation('XTRA', 520),
                        ui.FontVariation('YOPQ', 90),
                        ui.FontVariation('YTLC', 505),
                      ],
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      "Today's Mix for you",
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 0,
              child: Semantics(
                button: true,
                label: 'Shuffle Play',
                child: Material(
                  key: const ValueKey('home-shuffle-play'),
                  color: shuffleEnabled
                      ? colors.primary
                      : colors.tertiaryContainer,
                  shape: const RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.all(Radius.circular(68)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onPlay,
                    child: SizedBox.square(
                      dimension: 96,
                      child: Icon(
                        Icons.shuffle_rounded,
                        size: 36,
                        color: shuffleEnabled
                            ? colors.onPrimary
                            : colors.onTertiaryContainer,
                      ),
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

// Kept only until the remaining Home sections finish moving into source-named
// component files; the active implementation is [DailyMixSection].
// ignore: unused_element
class _DailyMix extends StatelessWidget {
  const _DailyMix({
    required this.songs,
    required this.onOpen,
    required this.onOpenAlbum,
  });

  final List<Song> songs;
  final VoidCallback onOpen;
  final ValueChanged<String> onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = AppScope.of(context);
    final displaySongs = songs.take(4).toList();
    final headerSongs = songs.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(30),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top Gradient Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.tertiary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAILY MIX',
                          style: TextStyle(
                            fontFamily: 'GoogleSansFlex',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: colors.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Based on History',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Overlapping avatar bubbles
                  SizedBox(
                    height: 44,
                    width: 100,
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        for (int i = 0; i < headerSongs.length; i++)
                          Positioned(
                            right: i * 24.0,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.surface,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: Artwork(
                                  colors: headerSongs[i].colors,
                                  mediaStoreId: headerSongs[i].mediaStoreId,
                                  borderRadius: 99,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Song list items (4 songs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: displaySongs.map((song) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => controller.playSong(song, fromQueue: songs),
                    onLongPress: () =>
                        onOpenAlbum('${song.albumId}:${song.album}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded),
                            onPressed: () =>
                                onOpenAlbum('${song.albumId}:${song.album}'),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Footer row
            InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Check all of Daily Mix',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: colors.onSurface,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _RecentlyPlayedSection extends StatelessWidget {
  const _RecentlyPlayedSection({required this.songs, required this.onOpenAll});

  final List<Song> songs;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    if (songs.length < 4) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final visibleSongs = songs.take(12).toList(growable: false);

    final row0 = <Song>[];
    final row1 = <Song>[];
    final row2 = <Song>[];

    for (var i = 0; i < visibleSongs.length; i++) {
      if (i % 3 == 0) {
        row0.add(visibleSongs[i]);
      } else if (i % 3 == 1) {
        row1.add(visibleSongs[i]);
      } else {
        row2.add(visibleSongs[i]);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recently played',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              IconButton.filledTonal(
                onPressed: onOpenAll,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                style: IconButton.styleFrom(
                  minimumSize: const Size(64, 40),
                  maximumSize: const Size(64, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: colors.surfaceContainerHigh,
                  foregroundColor: colors.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRow(context, row0),
              if (row1.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildRow(context, row1),
              ],
              if (row2.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildRow(context, row2),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<Song> rowSongs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rowSongs.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _RecentlyPlayedPill(song: rowSongs[i]),
        ],
      ],
    );
  }
}

class _RecentlyPlayedPill extends StatelessWidget {
  const _RecentlyPlayedPill({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final isCurrent = controller.currentSong?.id == song.id;
    final colors = Theme.of(context).colorScheme;

    final pillWidth = _resolvePillWidth(song.title, song.artist);
    final containerColor = isCurrent
        ? colors.primaryContainer
        : colors.surfaceContainerHigh;
    final textColor = isCurrent ? colors.onPrimaryContainer : colors.onSurface;

    return Container(
      width: pillWidth,
      height: 58,
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(isCurrent ? 14 : 29),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isCurrent ? 14 : 29),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => controller.playSong(song),
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 12),
            child: Row(
              children: [
                Artwork(
                  colors: song.colors,
                  size: 38,
                  borderRadius: 19,
                  mediaStoreId: song.mediaStoreId,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: textColor,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textColor.withValues(alpha: .75),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.equalizer_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _resolvePillWidth(String title, String artist) {
    final weighted = title.trim().length + (artist.trim().length * 0.55);
    if (weighted < 18) return 148;
    if (weighted < 28) return 166;
    if (weighted < 40) return 184;
    if (weighted < 54) return 202;
    return 220;
  }
}

// ignore: unused_element
class _StatsPreview extends StatelessWidget {
  const _StatsPreview({
    required this.onTap,
    required this.listeningTime,
    required this.totalPlays,
    required this.uniqueTracks,
  });

  final VoidCallback onTap;
  final Duration listeningTime;
  final int totalPlays;
  final int uniqueTracks;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        color: colors.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      color: colors.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Your listening',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: colors.onPrimaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        value: _formatDuration(listeningTime),
                        label: 'This month',
                      ),
                    ),
                    Expanded(
                      child: _Stat(value: '$totalPlays', label: 'Plays'),
                    ),
                    Expanded(
                      child: _Stat(value: '$uniqueTracks', label: 'Tracks'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
