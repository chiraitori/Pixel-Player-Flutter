# PixelPlayer Kotlin → Flutter parity matrix

This file is the source-of-truth for the port. A feature is only marked
`COMPLETE` after its Kotlin UI, state, persistence, side effects, empty/error
states, and Android integration have been checked against the cited source
files and covered by Flutter tests.

Status values:

- `COMPLETE`: source-audited and functionally implemented.
- `IN_PROGRESS`: real implementation exists but source parity is still being audited.
- `SCAFFOLDED`: destination file exists with a source contract; implementation is pending.
- `MISSING`: no Flutter destination yet.

## Application shell and player

| Kotlin source | Flutter destination | Status |
|---|---|---|
| `presentation/components/MainScreen.kt` and navigation components | `lib/features/shell/app_shell.dart` | IN_PROGRESS |
| `presentation/components/MiniPlayer.kt` | `lib/features/player/mini_player.dart` | IN_PROGRESS |
| `presentation/components/FullScreenPlayer.kt` and player subcomponents | `lib/features/player/full_player.dart`, `lib/features/player/*` | IN_PROGRESS |
| playback service, queue, session and preferences repositories | `lib/core/state/app_controller.dart` | IN_PROGRESS |

## Primary screens

| Kotlin source | Flutter destination | Status |
|---|---|---|
| `presentation/screens/SetupScreen.kt` | `lib/features/setup/setup_screen.dart` | IN_PROGRESS |
| `presentation/screens/HomeScreen.kt` | `lib/features/home/home_screen.dart` | IN_PROGRESS |
| `presentation/screens/SearchScreen.kt` | `lib/features/search/search_screen.dart` | IN_PROGRESS |
| `presentation/screens/LibraryScreen.kt` and library tab sources | `lib/features/library/library_screen.dart`, `lib/features/library/tabs/*` | IN_PROGRESS |
| `presentation/screens/SettingsScreen.kt` | `lib/features/settings/settings_screen.dart` | IN_PROGRESS |
| `presentation/screens/SettingsCategoryScreen.kt` | `lib/features/settings/settings_detail_screen.dart` | IN_PROGRESS |
| `presentation/screens/StatsScreen.kt` | `lib/features/stats/stats_screen.dart` | IN_PROGRESS |
| `presentation/screens/AccountsScreen.kt` | `lib/features/accounts/accounts_screen.dart` | IN_PROGRESS |

## Detail and utility screens

| Kotlin source | Flutter destination | Status |
|---|---|---|
| `AlbumDetailScreen.kt`, `ArtistDetailScreen.kt`, `GenreDetailScreen.kt`, `PlaylistDetailScreen.kt` | `lib/features/details/media_detail_screen.dart` | IN_PROGRESS |
| `CreatePlaylistScreen.kt` | `lib/features/library/create_playlist_screen.dart` | IN_PROGRESS |
| `EqualizerScreen.kt` | `lib/features/equalizer/equalizer_screen.dart` | IN_PROGRESS |
| `MashupScreen.kt` | `lib/features/mashup/mashup_screen.dart` | IN_PROGRESS |
| `EditTransitionScreen.kt` | `lib/features/playback/edit_transition_screen.dart` | IN_PROGRESS |
| `DeviceCapabilitiesScreen.kt` | `lib/features/settings/device_capabilities_screen.dart` | IN_PROGRESS |
| `ExperimentalSettingsScreen.kt` | `lib/features/settings/experimental_settings_screen.dart` | IN_PROGRESS |
| `PaletteStyleSettingsScreen.kt` | `lib/features/appearance/palette_style_screen.dart` | IN_PROGRESS |
| `NavBarCornerRadiusScreen.kt` | `lib/features/appearance/nav_bar_corner_radius_screen.dart` | IN_PROGRESS |
| `AboutScreen.kt` | `lib/features/about/about_screen.dart` | IN_PROGRESS |
| `ArtistSettingsScreen.kt` | `lib/features/artists/artist_settings_screen.dart` | SCAFFOLDED |
| `DailyMixScreen.kt` and `data/DailyMixManager.kt` | `lib/features/home/daily_mix_screen.dart`, `lib/data/mixes/daily_mix_manager.dart` | IN_PROGRESS |
| `DelimiterConfigScreen.kt` | `lib/features/settings/delimiter_config_screen.dart` | SCAFFOLDED |
| `WordDelimiterConfigScreen.kt` | `lib/features/settings/word_delimiter_config_screen.dart` | SCAFFOLDED |
| `EasterEggScreen.kt` | `lib/features/about/easter_egg_screen.dart` | SCAFFOLDED |
| `FolderExplorerScreen.kt` | `lib/features/library/folder_explorer_screen.dart` | SCAFFOLDED |
| `OpenSourceLicensesScreen.kt` | `lib/features/about/open_source_licenses_screen.dart` | SCAFFOLDED |
| `QuickFillScreen.kt` | `lib/features/library/quick_fill_screen.dart` | SCAFFOLDED |
| `RecentlyPlayedScreen.kt` and range selector | `lib/features/home/recently_played_screen.dart` | IN_PROGRESS |

## Implementation order

1. Read the complete Kotlin source file and directly referenced UI/state files.
2. Record its routes, states, actions, persistence keys, and platform calls in the destination Dart file.
3. Implement the Flutter UI using the same hierarchy, spacing, typography, colors, animations, sheets, and responsive branches.
4. Replace every action with a real implementation or an explicit platform/provider adapter.
5. Add widget/unit tests for normal, empty, loading, error, and interaction states.
6. Run formatter, analyzer, tests, and an Android APK build.
7. Mark the row `COMPLETE` only after a final source diff audit.

The Kotlin tree currently contains 572 source files: 255 data files, 252
presentation files, 34 utilities, 23 UI/theme/widget files, three DI files,
and five application/root files. The matrix will expand as each source slice
is audited; a broad screen label never implies that its supporting files were
silently skipped.

## Mirrored Flutter architecture

The Flutter port follows the Kotlin responsibilities even where Dart naming
differs:

| Kotlin package | Flutter package |
|---|---|
| `data/preferences` | `lib/data/preferences` |
| `data/database`, `data/repository`, `data/media` | `lib/data/library` |
| `data/service`, playback service classes | `lib/data/playback` |
| `data/backup` | `lib/data/backup` |
| `data/stats` | `lib/data/stats` |
| provider packages (`jellyfin`, `navidrome`, `gdrive`, `telegram`, `netease`, `qqmusic`) | `lib/data/providers/<provider>` |
| `presentation/viewmodel` | `lib/features/<feature>/state` |
| `presentation/screens` | `lib/features/<feature>` |
| `presentation/components` | feature-local `widgets` folders or `lib/shared/widgets` |
| `ui/theme` and `utils/shapes` | `lib/core/theme` and `lib/shared/shapes` |

Existing functionality is being extracted from the temporary
`AppController` coordinator into these repositories one source slice at a
time. Files in a scaffolded folder are contracts, not claims of completion.
