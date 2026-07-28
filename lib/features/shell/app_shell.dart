import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import '../about/about_screen.dart';
import '../accounts/accounts_screen.dart';
import '../appearance/nav_bar_corner_radius_screen.dart';
import '../appearance/palette_style_screen.dart';
import '../artists/artist_settings_screen.dart';
import '../details/artist_detail_screen.dart';
import '../details/media_detail_screen.dart';
import '../details/playlist_detail_screen.dart';
import '../equalizer/equalizer_screen.dart';
import '../home/home_screen.dart';
import '../home/daily_mix_screen.dart';
import '../home/recently_played_screen.dart';
import '../library/library_screen.dart';
import '../library/create_playlist_screen.dart';
import '../mashup/mashup_screen.dart';
import '../player/dismiss_undo_bar.dart';
import '../player/full_player.dart';
import '../player/mini_player.dart';
import '../playback/edit_transition_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_detail_screen.dart';
import '../settings/device_capabilities_screen.dart';
import '../settings/delimiter_config_screen.dart';
import '../settings/experimental_settings_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/word_delimiter_config_screen.dart';
import '../stats/stats_screen.dart';
import 'player_internal_navigation_bar.dart';
import 'player_route_overlay.dart';

/// Material 3 Expressive default spatial spring used by the Kotlin player
/// sheet (stiffness 380, damping ratio 0.8).
class _ExpressiveDefaultSpatialCurve extends Curve {
  const _ExpressiveDefaultSpatialCurve();

  static const _stiffness = 380.0;
  static const _dampingRatio = .8;
  static const _responseSeconds = .46;

  @override
  double transformInternal(double t) {
    final angularFrequency = math.sqrt(_stiffness);
    final dampedFrequency =
        angularFrequency * math.sqrt(1 - _dampingRatio * _dampingRatio);
    final elapsed = t * _responseSeconds;
    final decay = math.exp(-_dampingRatio * angularFrequency * elapsed);
    return (1 -
            decay *
                (math.cos(dampedFrequency * elapsed) +
                    (_dampingRatio * angularFrequency / dampedFrequency) *
                        math.sin(dampedFrequency * elapsed)))
        .clamp(0, 1);
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final transitionDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 460);
    const spatialCurve = _ExpressiveDefaultSpatialCurve();
    final systemNavBarInset = sanitizeNavigationBarBottomInset(
      MediaQuery.viewPaddingOf(context).bottom,
    );
    final floatingHorizontalPadding = systemNavBarInset > 30
        ? 14.0
        : systemNavBarInset;
    final useSmoothCorners = controller.boolSetting(
      'appearance_smooth_corners',
      true,
    );
    final navBarTopRadius =
        controller.navBarStyle == PixelNavBarStyle.floating &&
            controller.currentSong != null
        ? 10.0
        : controller.navBarCornerRadius;
    final navBarBottomRadius =
        controller.navBarStyle == PixelNavBarStyle.fullWidth
        ? 0.0
        : controller.navBarCornerRadius;
    return PopScope(
      canPop: !controller.fullPlayerVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && controller.fullPlayerVisible) {
          controller.hideFullPlayer();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(
              index: controller.selectedTab,
              children: [
                TickerMode(
                  enabled: controller.selectedTab == 0,
                  child: HomeScreen(
                    onOpenSettings: () => _openSettings(context),
                    onOpenDailyMix: () =>
                        _push(context, const DailyMixScreen()),
                    onOpenRecentlyPlayed: () =>
                        _push(context, const RecentlyPlayedScreen()),
                    onOpenStats: () => _push(context, const StatsScreen()),
                    onOpenAccounts: () =>
                        _push(context, const AccountsScreen()),
                    onOpenAlbum: (id) =>
                        _openMedia(context, MediaDetailType.album, id),
                  ),
                ),
                TickerMode(
                  enabled: controller.selectedTab == 1,
                  child: SearchScreen(
                    onOpenAlbum: (id) =>
                        _openMedia(context, MediaDetailType.album, id),
                    onOpenArtist: (id) =>
                        _openMedia(context, MediaDetailType.artist, id),
                    onOpenPlaylist: (id) =>
                        _openMedia(context, MediaDetailType.playlist, id),
                    onOpenGenre: (id) =>
                        _openMedia(context, MediaDetailType.genre, id),
                    onOpenSettings: () => _openSettings(context),
                  ),
                ),
                TickerMode(
                  enabled: controller.selectedTab == 2,
                  child: LibraryScreen(
                    onOpenSettings: () => _openSettings(context),
                    onOpenAlbum: (id) =>
                        _openMedia(context, MediaDetailType.album, id),
                    onOpenArtist: (id) =>
                        _openMedia(context, MediaDetailType.artist, id),
                    onOpenPlaylist: (id) =>
                        _openMedia(context, MediaDetailType.playlist, id),
                    onOpenGenre: (id) =>
                        _openMedia(context, MediaDetailType.genre, id),
                    onCreatePlaylist: () =>
                        _push(context, const CreatePlaylistScreen()),
                  ),
                ),
              ],
            ),
            IgnorePointer(
              ignoring: !controller.fullPlayerVisible,
              child: AnimatedSlide(
                duration: transitionDuration,
                curve: spatialCurve,
                offset: controller.fullPlayerVisible
                    ? Offset.zero
                    : const Offset(0, 1),
                child: AnimatedBuilder(
                  animation: controller.fullPlayerDragOffset,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, controller.fullPlayerDragOffset.value),
                    child: child,
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: controller.fullPlayerVisible ? 0 : 32),
                    duration: transitionDuration,
                    curve: spatialCurve,
                    builder: (context, topRadius, child) => Material(
                      color: Colors.transparent,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(topRadius),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: child,
                    ),
                    child: TickerMode(
                      enabled: controller.fullPlayerVisible,
                      child: Builder(
                        builder: (context) {
                          final mediaQuery = MediaQuery.of(context);
                          final padding = mediaQuery.padding;
                          return MediaQuery(
                            data: mediaQuery.copyWith(
                              padding: EdgeInsets.fromLTRB(
                                padding.left,
                                padding.top,
                                padding.right,
                                mediaQuery.viewPadding.bottom,
                              ),
                            ),
                            child: const FullPlayer(),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: IgnorePointer(
          ignoring: controller.fullPlayerVisible,
          child: AnimatedSlide(
            duration: transitionDuration,
            curve: spatialCurve,
            offset: controller.fullPlayerVisible
                ? const Offset(0, 1)
                : Offset.zero,
            child: AnimatedOpacity(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              opacity: controller.fullPlayerVisible ? 0 : 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: transitionDuration,
                    reverseDuration: transitionDuration,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: spatialCurve,
                                ),
                              ),
                          child: child,
                        ),
                      );
                    },
                    child: controller.showDismissUndoBar
                        ? Padding(
                            key: const ValueKey('dismiss-undo-bar'),
                            padding: const EdgeInsets.fromLTRB(
                              14,
                              0,
                              14,
                              miniPlayerBottomSpacer,
                            ),
                            child: DismissUndoBar(
                              duration: AppController.dismissUndoDuration,
                              onUndo: controller.undoDismissPlaylist,
                              onClose: controller.clearDismissedPlaylist,
                            ),
                          )
                        : const MiniPlayer(key: ValueKey('mini-player')),
                  ),
                  AnimatedPadding(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 460),
                    curve: spatialCurve,
                    padding: EdgeInsets.only(
                      left: controller.navBarStyle == PixelNavBarStyle.floating
                          ? floatingHorizontalPadding
                          : 0,
                      right: controller.navBarStyle == PixelNavBarStyle.floating
                          ? floatingHorizontalPadding
                          : 0,
                      bottom:
                          controller.navBarStyle == PixelNavBarStyle.floating
                          ? systemNavBarInset
                          : 0,
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: navBarTopRadius),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 460),
                      curve: spatialCurve,
                      builder: (context, animatedTopRadius, child) {
                        return TweenAnimationBuilder<double>(
                          tween: Tween(end: navBarBottomRadius),
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 460),
                          curve: spatialCurve,
                          child: child,
                          builder: (context, animatedBottomRadius, child) {
                            final borderRadius = BorderRadius.vertical(
                              top: Radius.circular(animatedTopRadius),
                              bottom: Radius.circular(animatedBottomRadius),
                            );
                            final shape = useSmoothCorners
                                ? RoundedSuperellipseBorder(
                                    borderRadius: borderRadius,
                                  )
                                : RoundedRectangleBorder(
                                    borderRadius: borderRadius,
                                  );
                            return Material(
                              elevation: 3,
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer,
                              shape: shape,
                              clipBehavior: Clip.antiAlias,
                              child: child,
                            );
                          },
                        );
                      },
                      child: PlayerInternalNavigationBar(
                        selectedIndex: controller.selectedTab,
                        onDestinationSelected: controller.selectTab,
                        onSearchDoubleTap: () => controller.selectTab(1),
                        style: controller.navBarStyle,
                        compactMode: controller.navBarCompactMode,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openMedia(BuildContext context, MediaDetailType type, String id) {
    if (type == MediaDetailType.artist) {
      _push(context, ArtistDetailScreen(artistId: id));
      return;
    }
    if (type == MediaDetailType.playlist) {
      _push(context, PlaylistDetailScreen(playlistId: id));
      return;
    }
    _push(context, MediaDetailScreen(type: type, id: id));
  }

  void _openSettings(BuildContext context) {
    _push(
      context,
      SettingsScreen(
        onBack: () => Navigator.pop(context),
        onOpenCategory: (id) => _openSettingsCategory(context, id),
        onOpenAccounts: () => _push(context, const AccountsScreen()),
        onOpenAbout: () => _push(context, const AboutScreen()),
      ),
    );
  }

  void _openSettingsCategory(BuildContext context, String id) {
    if (id == 'equalizer') {
      _push(context, const EqualizerScreen());
      return;
    }
    if (id == 'device_capabilities') {
      _push(context, const DeviceCapabilitiesScreen());
      return;
    }
    _push(
      context,
      SettingsDetailScreen(
        categoryId: id,
        onOpenScreen: (route) => _openSpecialty(context, route),
      ),
    );
  }

  void _openSpecialty(BuildContext context, String route) {
    if (route == 'transition') {
      AppScope.of(context).setStringSetting('transition_playlist_id', '');
    }
    final screen = switch (route) {
      'palette' => const PaletteStyleScreen(),
      'navbar' => const NavBarCornerRadiusScreen(),
      'transition' => const EditTransitionScreen(),
      'equalizer' => const EqualizerScreen(),
      'mashup' => const MashupScreen(),
      'experimental' => const ExperimentalSettingsScreen(),
      'artist-settings' => ArtistSettingsScreen(
        onOpenCharacterDelimiters: () =>
            _push(context, const DelimiterConfigScreen()),
        onOpenWordDelimiters: () =>
            _push(context, const WordDelimiterConfigScreen()),
      ),
      _ => const SizedBox.shrink(),
    };
    _push(context, screen);
  }

  void _push(BuildContext context, Widget screen) {
    final screenHostsPlayer =
        screen is DailyMixScreen ||
        screen is RecentlyPlayedScreen ||
        screen is StatsScreen ||
        screen is ArtistDetailScreen ||
        screen is PlaylistDetailScreen ||
        screen is EqualizerScreen ||
        screen is SettingsScreen;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            screenHostsPlayer ? screen : PlayerRouteOverlay(child: screen),
      ),
    );
  }
}
