# Kotlin Player - Full UI Positions, Shapes & Dimensions Reference

> Verified against `PixelPlayer/` source code (line-by-line cross-reference)
> All values in `dp` unless noted. Colors reference `MaterialTheme.colorScheme` via `LocalMaterialTheme`.
> Source files are under `app/src/main/java/com/theveloper/pixelplay/presentation/components/`

---

## TABLE OF CONTENTS

1. [Constants & Global Values](#0-constants--global-values)
2. [Sheet & Container](#1-sheet--container)
3. [MiniPlayer (Collapsed)](#2-minplayer-collapsed)
4. [FullPlayer Container & Visual State](#3-fullplayer-container--visual-state)
5. [TopAppBar](#4-topappbar)
6. [Album Cover / Carousel](#5-album-cover--carousel)
7. [Song Metadata Section](#6-song-metadata-section)
8. [Progress / Seek Bar](#7-progress--seek-bar)
9. [Playback Controls](#8-playback-controls)
10. [Bottom Toggle Row](#9-bottom-toggle-row)
11. [Internal Navigation Bar](#10-internal-navigation-bar)
12. [Lyrics Sheet Player Controls](#11-lyrics-sheet-player-controls)
13. [Queue Bottom Sheet](#12-queue-bottom-sheet)
14. [Cast Bottom Sheet](#13-cast-bottom-sheet)
15. [Animation Specs](#14-animation-specs)
16. [Color Tokens](#15-color-tokens)

---

## 0. Constants & Global Values

Source: `UnifiedPlayerSheetShared.kt`, `PlayerInternalNavigationBar.kt`, `FullPlayerContent.kt`

| Constant | Value | File |
|---|---|---|
| `MiniPlayerHeight` | `64.dp` | UnifiedPlayerSheetShared.kt:53 |
| `MiniPlayerBottomSpacer` | `8.dp` | UnifiedPlayerSheetShared.kt:55 |
| `ANIMATION_DURATION_MS` | `255` (ms) | UnifiedPlayerSheetShared.kt:54 |
| `NavBarContentHeight` | `90.dp` | PlayerInternalNavigationBar.kt:38 |
| `NavBarCompactContentHeight` | `64.dp` | PlayerInternalNavigationBar.kt:39 |
| `MaxNavigationBarBottomInset` | `96.dp` | PlayerInternalNavigationBar.kt:43 |
| `PREVIOUS_TRACK_RESTART_THRESHOLD_MS` | `10_000L` (ms) | FullPlayerContent.kt:152 |
| `SKIP_COMMAND_GUARD_MS` | `96L` (ms) | FullPlayerContent.kt:153 |

### LocalMaterialTheme
```kotlin
// compositionLocalOf<ColorScheme> — provides per-player-scope color scheme
// FullPlayer uses albumColorScheme (dynamic from album art)
// MiniPlayer uses miniPlayerScheme
```

### Key Color Aliases (FullPlayer)
```kotlin
playerOnBaseColor = LocalMaterialTheme.current.onPrimaryContainer
playerAccentColor = LocalMaterialTheme.current.primary
playerOnAccentColor = LocalMaterialTheme.current.onPrimary
progressActiveColor = playerOnBaseColor  // same as onPrimaryContainer
placeholderColor = playerOnBaseColor.copy(alpha = 0.1f)
placeholderOnColor = playerOnBaseColor.copy(alpha = 0.2f)
```

---

## 1. Sheet & Container

Source: `UnifiedPlayerSheetV2.kt`, `UnifiedPlayerSheetLayers.kt`, `SheetVisualState.kt`

| Property | Value |
|---|---|
| Collapsed horizontal padding | `12.dp` (default) / `14.dp` (FULL_WIDTH nav) |
| Expanded horizontal padding | `0.dp` (lerps from collapsed) |
| Top corner radius (collapsed, DEFAULT nav) | `navBarCornerRadiusDp` (configurable) |
| Top corner radius (collapsed, FULL_WIDTH nav) | `32.dp` |
| Top corner radius (collapsed, nav hidden) | `32.dp` |
| Top corner radius (expanded) | `0.dp` |
| Bottom corner radius (collapsed, DEFAULT nav) | `10.dp` |
| Bottom corner radius (collapsed, FULL_WIDTH nav) | `32.dp` |
| Bottom corner radius (collapsed, nav hidden) | `32.dp` |
| Bottom corner radius (expanded) | `0.dp` |
| Shadow elevation (collapsed, playing) | `3.dp * miniReadyAlpha` |
| Shadow elevation (expanded / dragging / queue) | `0.dp` |
| Card shadow shape | `PlayerSheetDynamicShape` (animates corners) |

### FullPlayer Visual Entrance
| Property | Value |
|---|---|
| contentAlpha | `(expansionFraction - 0.25f) / 0.75f` clamped 0..1 |
| translationY | `lerp(24.dp.toPx(), 0, contentAlpha)` |
| Scale (when bottom sheet open) | `lerp(1f, 0.972f, bottomSheetOpenFraction)` |
| Overshoot scale-Y on expand | `1.0 → 1.05 → 1.0` over 250ms keyframes |
| Bounce scale-Y on collapse | `0.96 → 1.0` spring(DampingRatioMediumBouncy, StiffnessLow) |

---

## 2. MiniPlayer (Collapsed)

Source: `UnifiedPlayerSheetShared.kt`

```
Row(fillMaxWidth, height = 64.dp, padding(start = 10.dp, end = 12.dp))
├── Box (album art)
│   └── SmartImage(size = 44.dp, shape = CircleShape)
│       └── CircularProgressIndicator(size = 24.dp, stroke = 2.dp) [if casting]
│       └── CircularWavyProgressIndicator(size = 24.dp) [if preparing]
├── Spacer(width = 12.dp)
├── Column(weight = 1f, Arrangement.Center)
│   ├── AutoScrollingText (title)
│   │   style: titleSmall, 15.sp, SemiBold, letterSpacing=-0.2.sp, GoogleSansRounded
│   │   color: onPrimaryContainer
│   └── AutoScrollingText (artist)
│       style: bodySmall, 13.sp, letterSpacing=0.sp, GoogleSansRounded
│       color: onPrimaryContainer.copy(alpha=0.7f)
├── Spacer(width = 8.dp)
├── Box (Previous) ─ 36.dp, CircleShape, bg=onPrimary, icon=22.dp, tint=primary
├── Spacer(width = 8.dp)
├── Box (PlayPause) ─ 36.dp, CircleShape, bg=primary, icon=22.dp, tint=onPrimary
├── Spacer(width = 8.dp)
└── Box (Next) ─ 36.dp, CircleShape, bg=onPrimary, icon=22.dp, tint=primary
```

| Constant | Value |
|---|---|
| `MiniPlayerHeight` | `64.dp` |
| `MiniPlayerBottomSpacer` | `8.dp` |
| Album art target size | `150x150 px` (Coil) |
| MiniPlayer alpha | `(1f - expansionFraction * 2f)` clamped 0..1 |
| MiniPlayer zIndex | `1f` when fraction < 0.5, else `0f` |

---

## 3. FullPlayer Container & Visual State

Source: `UnifiedPlayerSheetLayers.kt`, `FullPlayerVisualState.kt`

| Property | Value |
|---|---|
| FullPlayer alpha | `(fraction - 0.25f) / 0.75f` clamped 0..1 |
| FullPlayer translationY | `lerp(24.dp → 0, contentAlpha)` |
| FullPlayer scale | `lerp(1f, 0.972f, bottomSheetOpenFraction)` |
| FullPlayer zIndex | `1f` when fraction >= 0.5, else `0f` |
| FullPlayer offset when hidden | `IntOffset(0, 10000)` |

### Portrait Layout
```
Column(fillMaxSize, padding(horizontal=24.dp, vertical=0.dp), SpaceAround)
├── albumCoverSection
├── Column(fillMaxWidth, spacedBy=4.dp)
│   ├── Box(align=Start) → songMetadataSection
│   └── playerProgressSection
└── controlsSection
```

### Landscape Layout
```
Row(fillMaxSize, padding(horizontal=24.dp, vertical=0.dp), CenterVertically)
├── albumCoverSection(fillMaxHeight, weight=1f)
├── Spacer(width=9.dp)
└── Column(fillMaxHeight, weight=1f, SpaceEvenly, CenterHorizontally)
    ├── songMetadataSection
    ├── playerProgressSection
    └── controlsSection
```

---

## 4. TopAppBar

Source: `FullPlayerContent.kt:673-898` (portrait only, hidden in landscape)

### Navigation (Collapse Button)
| Property | Value |
|---|---|
| Container | `Box(width=56.dp, height=42.dp, alignment=CenterEnd)` |
| Button | `Box(size=42.dp, CircleShape, bg=onAccentColor*0.7)` |
| Icon | `rounded_keyboard_arrow_down_24`, tint=`accentColor` |

### Title
| Property | Value |
|---|---|
| Text | "Now Playing" (string resource) |
| Padding start | `18.dp` |
| Style | `labelLargeEmphasized` |
| FontWeight | `SemiBold` |
| Color | `onPrimaryContainer` |
| Cloud icon (if telegram) | `size=16.dp`, paddingStart=`8.dp`, tint=`onPrimaryContainer*0.6` |

### Actions Row
| Property | Value |
|---|---|
| Row | `padding(end=14.dp)`, `spacedBy(6.dp)`, `CenterVertically` |

#### Cast/Bluetooth Button
| Property | Value |
|---|---|
| Container Box | `height=42.dp`, `widthIn(min=50.dp, max=58.dp or 190.dp)` |
| Corner shape | Animated: expanded=`50.dp` all, compact=`topStart=50, topEnd=6, bottomStart=50, bottomEnd=6` |
| Background | `onAccentColor.copy(alpha=0.7f)` |
| Icon tint | `accentColor` |
| Label spacing | `12.dp` between icon and text |
| Label padding end | `16.dp` |
| Active dot | `8.dp` circle, `onTertiaryContainer` |

#### Queue Button
| Property | Value |
|---|---|
| Size | `height=42.dp, width=50.dp` |
| Shape | `RoundedCornerShape(topStart=6, topEnd=50, bottomStart=6, bottomEnd=50)` |
| Background | `onAccentColor.copy(alpha=0.7f)` |
| Icon | `rounded_queue_music_24`, tint=`accentColor` |

### TopBar Animations
| Event | Enter | Exit |
|---|---|---|
| Portrait show/hide | `fadeIn(350ms) + slideInVertically(-it/2, 350ms)` | `fadeOut(220ms) + slideOutVertically(-it/2, 220ms)` |
| Alpha with expansion | `((fraction - 0) / 1).coerceIn(0,1)` | same |

---

## 5. Album Cover / Carousel

Source: `FullPlayerContent.kt:1002-1107`, `AlbumCarouselSelection.kt`, `RoundedParallaxCarousell.kt`

### Album Cover Section
| Property | Value |
|---|---|
| Outer padding | `vertical = 8.dp` |
| Scale (playing) | `1.0f` |
| Scale (paused, !playWhenReady) | `0.95f` |
| Scale animation | `tween(260ms, FastOutSlowInEasing)` |
| Placeholder corner radius | `18.dp` |
| Placeholder icon | `pixelplay_base_monochrome`, `size=86.dp` |

### Carousel Heights
| Style | Focused item size | Peek item size | Max peek count |
|---|---|---|---|
| `NO_PEEK` | `100%` of maxWidth | none | 0 |
| `ONE_PEEK` | `80%` of maxWidth | `80%` (aligned Start) | 1 |
| `TWO_PEEK` | `60%` of maxWidth | `45%` of maxWidth | 2 |
| Single item | Forced `NO_PEEK` | - | 0 |

### Carousel Item
| Property | Value |
|---|---|
| Item corner radius | `18.dp` |
| Item spacing | `8.dp` |
| Aspect ratio | `1:1` (square) |
| Clip shape | Custom `Shape` using `maskRect` intersection |
| Animation spec | `spring(DampingRatioNoBouncy, StiffnessMediumLow)` |
| Alpha (ONE_PEEK, items beyond focus) | `0f` with `tween(200ms)` |

---

## 6. Song Metadata Section

Source: `FullPlayerContent.kt:1303-1610`

### Container (`SongMetadataDisplaySection`)
| Property | Value |
|---|---|
| Min height | `70.dp` |
| Layout | `Row(fillMaxWidth, heightIn(min=70.dp))` |
| Spacing | `12.dp` between items |
| Vertical alignment | `CenterVertically` |

### Song Info (`PlayerSongInfo`)
| Property | Value |
|---|---|
| Column | `padding(vertical=4.dp)`, `fillMaxWidth` |
| graphicsLayer alpha | `expansionFraction` |
| graphicsLayer translationY | `(1f - expansionFraction) * 24f` |
| Title style | `headlineSmall, FontWeight.Bold, GoogleSansRounded` |
| Artist style | `titleMedium, letterSpacing=0.sp, color=textColor*0.7` |
| Spacer (title→artist) | `2.dp` |

### Buffering Indicator
| Property | Value |
|---|---|
| Surface | `CircleShape`, `padding(end=8.dp)` |
| Inner padding | `10.dp` |
| LoadingIndicator | `size=28.dp` |
| Enter | `scaleIn(0.85f, 400ms, 80ms delay) + fadeIn(300ms, 80ms delay)` |
| Exit | `scaleOut(0.85f, 300ms) + fadeOut(200ms)` |

### Lyrics Button (Portrait)
| Property | Value |
|---|---|
| Type | `FilledIconButton` |
| Size | `48.dp x 48.dp` |
| Container color | `playerOnAccentColor.copy(alpha=0.8f)` |
| Content color | `playerAccentColor` |
| Icon | `rounded_lyrics_24` |

### Lyrics + Queue Buttons (Landscape)
| Property | Value |
|---|---|
| Button size | `height=42.dp, width=50.dp` |
| Spacing | `6.dp` |
| Lyrics shape | `RoundedCornerShape(topStart=50, topEnd=6, bottomStart=50, bottomEnd=6)` |
| Queue shape | `RoundedCornerShape(topStart=6, topEnd=50, bottomStart=6, bottomEnd=50)` |
| Background | `chipColor` |
| Icon tint | `chipContentColor` |

---

## 7. Progress / Seek Bar

Source: `FullPlayerContent.kt:1631-1968`, `WavySliderExpressive.kt`, `PlayerSeekBar.kt`

### Progress Section Container
| Property | Value |
|---|---|
| Min height | `70.dp` |
| Layout | `Column(fillMaxWidth, heightIn(min=70.dp))` |

### WavySliderExpressive (Main Slider)
| Property | Value |
|---|---|
| Container height | `max(LinearContainerHeight, max(thumbRadius*2, lineHeight))` |
| Padding | `vertical=8.dp, horizontal=0.dp` |
| Stroke width | `5.dp` |
| Stroke cap | `StrokeCap.Round` |
| Thumb radius | `8.dp` (idle) → `strokeWidth*0.6` (dragging) |
| Thumb shape | `RoundRect` with `CornerRadius = width/2` (pill) |
| Thumb idle size | `width=thumbRadius*2, height=thumbRadius*2` |
| Thumb dragging size | `width=strokeWidth*1.2, height=lineHeight(24.dp)` |
| Wavelength | `30.dp` (default) |
| Wave speed | `wavelength / 2` |
| Wave amplitude (playing) | `4.dp` |
| Wave amplitude (paused/dragging) | `0f` |
| Gap size (idle) | `6.dp` |
| Gap size (dragging) | `currentHalfWidth + 1.2.dp` |
| Stop size | `3.dp` |
| Track edge padding | `thumbRadius` (default) |
| Active track color | `playerOnBaseColor` |
| Inactive track color | `playerOnBaseColor.copy(alpha=0.2f)` |
| Thumb color | `playerOnBaseColor` |
| Interaction animation | `tween(250ms, FastOutSlowInEasing)` |

### Time Labels (`EfficientTimeLabels`)
| Property | Value |
|---|---|
| Position text | Left-aligned, `bodySmall, 12.sp, SemiBold` |
| Duration text | Right-aligned, `bodySmall, 12.sp, SemiBold` |
| Color | `playerOnBaseColor` |
| Layout | `Row(fillMaxWidth, SpaceBetween)` |

### Audio Meta Label (centered chip)
| Property | Value |
|---|---|
| Alignment | `Center` |
| Padding horizontal | `58.dp` (from parent Box) |
| Surface shape | `RoundedCornerShape(999.dp)` |
| Background | `textColor.copy(alpha=0.14f)` |
| Content color | `textColor.copy(alpha=0.96f)` |
| Text | `labelSmall, FontWeight.Medium, 11.sp` |
| Text padding | `horizontal=10.dp, vertical=3.dp` |
| Max lines | `1` |

### PlayerSeekBar (Lyrics Sheet variant)
| Property | Value |
|---|---|
| Container | `CircleShape`, `shadow(elevation=8.dp)`, `background(backgroundColor)` |
| Padding | `horizontal=16.dp, vertical=0.dp` |
| Spacing | `8.dp` between slider and labels |
| Slider | Same WavySliderExpressive with `strokeWidth=5.dp, thumbRadius=8.dp, wavelength=30.dp` |

---

## 8. Playback Controls

Source: `FullPlayerContent.kt:1109-1196`, `AnimatedPlaybackControls.kt`

### Controls Section Container
| Property | Value |
|---|---|
| Total height | `182.dp` |
| Layout | `Column(fillMaxWidth, CenterHorizontally)` |
| DelayedContent bounds | `fillMaxWidth().height(182.dp)` |

### AnimatedPlaybackControls
| Property | Value |
|---|---|
| Outer padding | `horizontal=12.dp, vertical=8.dp` |
| Height | `80.dp` (passed from ControlsSection) |
| Layout | `Row(fillMaxSize, spacedBy=6.dp, CenterVertically)` |
| Base weight (all) | `1.0f` |
| Expansion weight (pressed) | `1.1f` |
| Compression weight (others) | `0.65f` |
| Release delay | `220ms` |

### Previous Button
| Property | Value |
|---|---|
| Shape | `CircleShape` |
| Background | `secondaryFixedDim` |
| Icon | `Icons.Rounded.SkipPrevious` |
| Icon size | `32.dp` |
| Icon tint | `onSecondaryFixed` |
| Click delay before action | `180ms` |

### Play/Pause Button
| Property | Value |
|---|---|
| Shape | `AbsoluteSmoothCornerShape` (animated corners) |
| Corner radius (playing state) | `26.dp` — more square, matches pause icon silhouette |
| Corner radius (paused state) | `60.dp` — more round, matches play triangle silhouette |
| Source param mapping | `!playPauseVisualState → playPauseCornerPlaying(60.dp)`, `playPauseVisualState → playPauseCornerPaused(26.dp)` |
| Smoothness (all corners) | `60%` |
| Corner animation | `motionScheme.defaultSpatialSpec<Dp>()` |
| Background | `tertiaryFixedDim` |
| Icon | `MorphingPlayPauseIcon` (Crossfade between PlayArrow/Pause) |
| Icon size | `36.dp` |
| Icon tint | `onTertiaryFixed` |
| Haptic on press | `TextHandleMove` |

### Next Button
| Property | Value |
|---|---|
| Shape | `CircleShape` |
| Background | `secondaryFixedDim` |
| Icon | `Icons.Rounded.SkipNext` |
| Icon size | `32.dp` |
| Icon tint | `onSecondaryFixed` |
| Click delay before action | `180ms` |

### Button Weight Animation on Press
```
When button X is pressed:
  X.weight → expansionWeight (1.1f)
  other.weight → compressionWeight (0.65f)
When no button pressed:
  all.weight → baseWeight (1.0f)
Animation: motionScheme.fastSpatialSpec<Float>()
```

---

## 9. Bottom Toggle Row

Source: `FullPlayerContent.kt:2544-2643`, `ToggleSegmentButton.kt`

### Container
| Property | Value |
|---|---|
| Height | `min=66.dp, max=86.dp` |
| Padding | `horizontal=26.dp, bottom=6.dp` |
| Background | `surfaceContainerLowest.copy(alpha=0.7f)` |
| Corner shape | `AbsoluteSmoothCornerShape(60.dp all corners, smoothness 60%)` |

### Inner Row
| Property | Value |
|---|---|
| Padding | `6.dp` all sides |
| Spacing | `6.dp` |
| Clip | Same `AbsoluteSmoothCornerShape(60.dp, 60%)` |
| Background | `Color.Transparent` |
| **Effective total padding from screen edge** | **Horizontal: `26.dp + 6.dp = 32.dp`**, **Bottom: `6.dp + 6.dp = 12.dp`** |

### ToggleSegmentButton
| Property | Value |
|---|---|
| Weight | `1f` (equal 3-way split) |
| Height | `fillMaxSize` (fills parent) |
| Icon size | `24.dp` |
| Content padding horizontal | `10.dp` |
| Active corner radius | `60.dp` (rowCorners) |
| Inactive corner radius | `8.dp` |
| Corner animation | `spring(stiffness=StiffnessLow)` |
| BG animation | `tween(250ms)` |
| Disabled alpha | `0.38f` |

### Toggle Colors
| Button | Active BG | Active Content | Inactive BG | Inactive Content |
|---|---|---|---|---|
| Shuffle | `primaryFixed` | `onPrimaryFixed` | `onSurface*0.07` | `onSurface` |
| Repeat | `secondaryFixed` | `onSecondaryFixed` | `onSurface*0.07` | `onSurface` |
| Favorite | `tertiaryFixed` | `onTertiaryFixed` | `onSurface*0.07` | `onSurface` |

### Repeat Icon Variants
| Mode | Icon |
|---|---|
| OFF | `rounded_repeat_24` |
| ONE | `rounded_repeat_one_24` |
| ALL | `rounded_repeat_24` |

---

## 10. Internal Navigation Bar

Source: `PlayerInternalNavigationBar.kt`, `CustomNavigationBarItem.kt`

### Bar Dimensions
| Property | Value |
|---|---|
| Content height (normal) | `90.dp` |
| Content height (compact) | `64.dp` |
| Max bottom inset | `96.dp` |
| MiniPlayer + spacer + extra | `64 + 8 + 8 = 80.dp` |

### Navigation Item Row
| Property | Value |
|---|---|
| Layout | `Row(fillMaxWidth, SpaceAround, CenterVertically)` |
| DEFAULT style padding | `start=10.dp, end=10.dp, bottom=innerRowPadding` |
| FULL_WIDTH style padding | `top=0, bottom=innerRowPadding, start=12.dp, end=12.dp` |

### CustomNavigationBarItem
| Property | Value |
|---|---|
| Layout | `Column(weight=1f, fillMaxHeight, CenterHorizontally, Center)` |
| Indicator container | `Box(size=64.dp x 32.dp)` |
| Indicator padding | `horizontal=4.dp` |
| Indicator shape | `RoundedCornerShape(16.dp)` |
| Indicator color | `secondaryContainer` |
| Icon area | `Box(size=48.dp x 24.dp)` |
| Icon shape | `RoundedCornerShape(12.dp)` |
| Icon scale (selected) | `1.1f` spring(MediumBouncy, Medium) |
| Icon scale (unselected) | `1.0f` |
| Icon color animation | `tween(150ms)` |
| Text color animation | `tween(150ms)` |
| Label | `labelMedium, 13.sp` |
| Label fontWeight (selected) | `Medium` |
| Label fontWeight (unselected) | `Normal` |
| Label spacer | `4.dp` height, `4.dp` top padding |
| Label enter | `fadeIn(200ms, delay=50ms)` |
| Label exit | `fadeOut(100ms)` |
| Indicator enter | `fadeIn(100ms) + scaleIn(spring(MediumBouncy, StiffnessLow))` |
| Indicator exit | `fadeOut(100ms) + scaleOut(tween(100ms, EaseInQuart))` |

---

## 11. Lyrics Sheet Player Controls

Source: `LyricsSheet.kt`

### Playback Controls Row
| Property | Value |
|---|---|
| Layout | `Row`, `fillMaxWidth()`, `Arrangement.spacedBy(12.dp)` |
| Vertical alignment | `CenterVertically` |

### Play/Pause Button (Lyrics)
| Property | Value |
|---|---|
| Size | `78.dp × 78.dp` |
| Shape | `RoundedCornerShape(playPauseCornerRadius)` |
| Corner radius (playing) | `18.dp` |
| Corner radius (paused) | `50.dp` |
| Corner animation | `spring(stiffness = Spring.StiffnessLow)` |
| Background | `playPauseColor` (= `sheetColors.playPauseContent`) |
| Icon | `AnimatedContent` crossfade: `Icons.Rounded.Pause` / `Icons.Rounded.PlayArrow` |
| Icon size | `32.dp` |
| Icon tint | `onPlayPauseColor` (= `sheetColors.playPauseContent`) |
| Haptic on press | `TextHandleMove` |

### Progress Bar (Lyrics)
| Property | Value |
|---|---|
| Modifier | `Modifier.weight(1f).height(50.dp)` |
| Implementation | `LyricsPlaybackSeekBar` → delegates to `PlayerSeekBar` |
| Colors | `backgroundColor`, `onBackgroundColor`, `accentColor` |
| Bottom spacer | `16.dp` |

### Floating Toolbar (Lyrics)
| Property | Value |
|---|---|
| Source | `LyricsFloatingToolbar.kt:58` |
| Horizontal padding | `0.dp` |
| Features | Synced lyrics toggle, Back button (with gesture animation), More button |
| Back button progress | `backProgressProvider` for gesture-based animation |

---

## 12. Queue Bottom Sheet

Source: `QueueBottomSheet.kt`, `UnifiedPlayerOverlaysLayer.kt`

### Sheet Container
| Property | Value |
|---|---|
| Modifier | `fillMaxSize()`, offset by `queueSheetOffset`, alpha animated |
| Shape | `RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)` |
| Tonal elevation | `10.dp` |
| Background color | `colors.surfaceContainer` |
| Overlay | `albumColorScheme` MaterialTheme wrapping |

### Drag Handle
| Property | Value |
|---|---|
| Width | `42.dp` |
| Height | `4.dp` |
| Shape | `CircleShape` |
| Color | `onSurface.copy(alpha = 0.14f)` |
| Top padding | `2.dp` |
| Bottom padding | `14.dp` |
| Header bottom padding | `12.dp` |

### Header Section
| Property | Value |
|---|---|
| Top padding | `WindowInsets.statusBars.topPadding + 10.dp` |
| Horizontal padding | `16.dp` |
| Vertical spacing | `14.dp` |
| Title | `headlineLarge`, `GoogleSansRounded`, `SemiBold` |
| Subtitle | `titleMedium` |
| Playback controls height | `70.dp` (play/pause/prev/next buttons) |
| Action button size | `48.dp` (shuffle/repeat/etc) |
| Locate button icon size | `18.dp × 16.dp` |

### Queue List (LazyColumn)
| Property | Value |
|---|---|
| Background | `surfaceContainerHigh` |
| Shape | `queueListShape` |
| Vertical spacing | `8.dp` |
| Top spacer | `6.dp` |
| Bottom padding | `MiniPlayerHeight + navBarBottomPadding + 32.dp` |
| End padding | `26.dp` when scrollbar visible |
| Item scale (dragging) | `1.015f` |
| Item scale animation | `spring(DampingRatioNoBouncy, StiffnessMediumLow)` |
| Reorder animation (no drag) | `fadeIn(140ms)`, `fadeOut(120ms)`, `placement(180ms)` |
| Reorder animation (dragging) | `spring(DampingRatioNoBouncy, StiffnessMediumLow)` |
| Drag threshold | `72.dp` |

### Item Layout
| Property | Value |
|---|---|
| Song title | `titleMedium`, `onSurface` |
| Artist | `bodyMedium`, `onSurfaceVariant` |
| Album art | Rounded corners (see `OptimizedAlbumArt`) |
| Drag handle size | `40.dp` |
| Reorder handle icon | `size(18.dp)`, `onSurfaceVariant` |
| Remove button | `size(36.dp)` |

### FAB (Floating Action Button)
| Property | Value |
|---|---|
| Expand/collapse | `isFabExpanded` state |
| Bottom sheet shape | `RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)` |

---

## 13. Cast Bottom Sheet

Source: `CastBottomSheet.kt`, `UnifiedPlayerOverlaysLayer.kt`

### Sheet Container
| Property | Value |
|---|---|
| Alignment | `BottomCenter` |
| Width | `fillMaxWidth()` |
| Window insets | `WindowInsets.navigationBars.only(Horizontal)` |
| Shape | `RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)` |
| Tonal elevation | `12.dp` |
| Background color | `surfaceContainerLow` |
| Content padding | `bottom = 18.dp` |
| Scrim | `scrim.copy(alpha = 0.45f)` when visible |
| Scrim animation | `tween(240ms, FastOutSlowInEasing)` |

### Animations
| Property | Value |
|---|---|
| Open animation | `tween(durationMillis = 220 + 130 * travelFraction, FastOutSlowInEasing)` |
| Close animation | `tween(durationMillis = 240, FastOutSlowInEasing)` |
| Snap back | `tween(durationMillis = 170 + 120 * travelFraction, FastOutSlowInEasing)` |
| Content alpha | `tween(200ms, FastOutSlowInEasing)` |

### Top Bar
| Property | Value |
|---|---|
| Implementation | `CollapsibleCastTopBar` |
| Content alpha | `1f - collapseFraction`, `tween(200ms, FastOutSlowInEasing)` |
| Features | Scanning indicator, WiFi/Bluetooth info, Connection status |

---

## 14. Animation Specs

### Constants
| Constant | Value | File |
|---|---|---|
| `ANIMATION_DURATION_MS` | `255` (ms) | UnifiedPlayerSheetShared.kt:54 |
| `PREVIOUS_TRACK_RESTART_THRESHOLD_MS` | `10_000L` (ms) | FullPlayerContent.kt:152 |
| `SKIP_COMMAND_GUARD_MS` | `96L` (ms) | FullPlayerContent.kt:153 |

### Component Animations

| Component | Animation | Spec |
|---|---|---|
| Album art scale | playing↔paused | `tween(260ms, FastOutSlowInEasing)` |
| Play/Pause corners | playing↔paused | `motionScheme.defaultSpatialSpec<Dp>()` |
| Button weight press | expansion/compression | `motionScheme.fastSpatialSpec<Float>()` |
| Play/Pause icon | crossfade | `motionScheme.fastEffectsSpec()` |
| Toggle BG color | active↔inactive | `tween(250ms)` |
| Toggle corner radius | active↔inactive | `spring(stiffness=StiffnessLow)` |
| Buffering indicator enter | scale+fade | `scaleIn(0.85f, 400ms, 80ms) + fadeIn(300ms, 80ms)` |
| Buffering indicator exit | scale+fade | `scaleOut(0.85f, 300ms) + fadeOut(200ms)` |
| TopBar enter (portrait) | slide+fade | `fadeIn(350ms) + slideInVertically(-it/2, 350ms)` |
| TopBar exit (portrait) | slide+fade | `fadeOut(220ms) + slideOutVertically(-it/2, 220ms)` |
| Metadata alpha | fade in | `(expansionFraction - 0) / 1` |
| Metadata translationY | slide up | `(1f - fraction) * 24f` px |
| FullPlayer contentAlpha | fade in | `(fraction - 0.25) / 0.75` |
| FullPlayer translationY | slide up | `lerp(24.dp → 0, contentAlpha)` |
| Sheet overshoot expand | scale bounce | `1.0 → 1.05 → 1.0` keyframes 250ms |
| Sheet bounce collapse | scale bounce | `0.96 → 1.0` spring(MediumBouncy, StiffnessLow) |
| Carousel scroll | snap | `spring(DampingRatioNoBouncy, StiffnessMediumLow)` |
| Carousel item alpha | ONE_PEEK hidden | `tween(200ms)` |
| WavySlider thumb | interaction | `tween(250ms, FastOutSlowInEasing)` |
| WavySlider wave amplitude | playing↔paused | `ProgressIndicatorDefaults.ProgressAnimationSpec` |
| DelayedContent blend in | alpha | `tween(260ms, FastOutSlowInEasing)` |
| DelayedContent blend out | alpha | `tween(140ms, FastOutSlowInEasing)` |
| DelayedContent placeholder in | alpha | `tween(360ms, FastOutSlowInEasing)` |
| DelayedContent placeholder out | alpha | `tween(140ms, FastOutSlowInEasing)` |
| Nav item indicator | enter | `fadeIn(100ms) + scaleIn(spring(MediumBouncy, Low))` |
| Nav item indicator | exit | `fadeOut(100ms) + scaleOut(tween(100ms, EaseInQuart))` |
| Nav item icon scale | selected bounce | `spring(MediumBouncy, Medium)` to `1.1f` |
| Lyrics play/pause corners | playing↔paused | `spring(stiffness = Spring.StiffnessLow)` — `18dp ↔ 50dp` |
| Cast sheet scrim | alpha | `tween(240ms, FastOutSlowInEasing)` — `0f → 0.45f` |
| Cast sheet content alpha | collapse fraction | `tween(200ms, FastOutSlowInEasing)` — `1f - collapseFraction` |
| Cast sheet open | slide up | `tween(220 + 130 * travelFraction ms, FastOutSlowInEasing)` |
| Cast sheet close | slide down | `tween(240ms, FastOutSlowInEasing)` |
| Cast sheet snap back | slide down | `tween(170 + 120 * travelFraction ms, FastOutSlowInEasing)` |
| Queue item reorder (no drag) | animateItem | `fadeIn(140ms)`, `fadeOut(120ms)`, `placement(180ms)` |
| Queue item reorder (dragging) | animateItem | `spring(DampingRatioNoBouncy, StiffnessMediumLow)` |
| Queue item scale (drag) | scale | `spring(DampingRatioNoBouncy, StiffnessMediumLow)` — `1f → 1.015f` |

---

## 15. Color Tokens

> Note: `transportSkipButtonColors` (= `playerAccentColor`/`playerOnAccentColor`) is defined at
> FullPlayerContent.kt:318-321 but **NOT used** in the actual controls section. The controls
> use `transportSkipColors` and `transportPlayPauseColors` from the expressive functions below.

| Token | Portrait (FullPlayer) | MiniPlayer |
|---|---|---|
| Container BG | `albumColorScheme` (dynamic from album art) | `miniPlayerScheme` |
| onPrimaryContainer | Text color (title, artist, time) | Text color, album loading |
| primary | Accent color | Play/Pause BG, Prev/Next icon tint |
| onPrimary | Play/Pause icon tint (mini) | Prev/Next button BG |
| primaryContainer | Gradient edge for text | Title gradient edge |
| onPrimaryFixed | Shuffle active content | - |
| primaryFixed | Shuffle active BG | - |
| onSecondaryFixed | Repeat active content, Skip button icon | - |
| secondaryFixedDim | Skip button BG (Prev/Next in full player) | - |
| secondaryFixed | Repeat active BG | - |
| onTertiaryFixed | Play/Pause icon tint (full player) | - |
| tertiaryFixedDim | Play/Pause button BG (full player) | - |
| tertiaryFixed | Favorite active BG | - |
| surfaceContainerLowest*0.7 | Toggle row container BG | - |
| onSurface*0.07 | Toggle inactive BG | - |
| onSurface | Toggle inactive content | - |
| surfaceContainer | - | (default M3) |
| secondaryContainer | Nav indicator | - |
| onSurfaceVariant | Nav unselected icon | - |

### Placeholder Colors
| Token | Value |
|---|---|
| placeholderColor | `playerOnBaseColor.copy(alpha = 0.1f)` |
| placeholderOnColor | `playerOnBaseColor.copy(alpha = 0.2f)` |
| Controls placeholder BG (play/pause) | `placeholderOnColor` (the `color` param) |
| Controls placeholder BG (prev/next) | `placeholderOnColor` (the `onColor` param) |
| Toggle placeholder | `placeholderOnColor.copy(alpha = 0.1f)` |
| Audio meta placeholder | `placeholderOnColor.copy(alpha = 0.15f)`, `widthIn(96-180.dp), height=18.dp` |
