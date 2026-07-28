import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/app.dart';
import 'package:pixelplayer_flutter/core/models/song.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/core/theme/genre_theme.dart';
import 'package:pixelplayer_flutter/core/theme/pixelplay_theme.dart';
import 'package:pixelplayer_flutter/features/player/cast_bottom_sheet.dart';
import 'package:pixelplayer_flutter/features/player/sleep_timer_bottom_sheet.dart';
import 'package:pixelplayer_flutter/features/player/song_info_bottom_sheet.dart';
import 'package:pixelplayer_flutter/features/player/wavy_slider.dart';
import 'package:pixelplayer_flutter/features/home/daily_mix_screen.dart';
import 'package:pixelplayer_flutter/features/search/search_screen.dart';
import 'package:pixelplayer_flutter/features/search/widgets/genre_categories_grid.dart';
import 'package:pixelplayer_flutter/features/search/widgets/search_result_media_card.dart';
import 'package:pixelplayer_flutter/features/shell/app_shell.dart';

import 'fixtures/mock_library.dart';

void main() {
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          if (call.method == 'checkPermissionStatus') return 1;
          if (call.method == 'requestPermissions') {
            final permissions = List<int>.from(call.arguments as List);
            return <int, int>{
              for (final permission in permissions) permission: 1,
            };
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  test('uses the Material 3 Expressive design system globally', () {
    final light = PixelPlayTheme.light();
    final dark = PixelPlayTheme.dark();
    final buttonStyle = light.filledButtonTheme.style!;

    expect(light.useMaterial3, isTrue);
    expect(dark.useMaterial3, isTrue);
    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(
      buttonStyle.minimumSize?.resolve(const <WidgetState>{}),
      const Size(64, 48),
    );
    expect(
      light.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<PredictiveBackPageTransitionsBuilder>(),
    );
    expect(light.navigationBarTheme.indicatorShape, isA<StadiumBorder>());
    expect(light.cardTheme.shape, isA<RoundedRectangleBorder>());
  });

  test('repairs every Material 3 tonal surface role from dynamic colors', () {
    final incompleteDynamicScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF46639A),
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF1A1B20),
          surfaceContainerLowest: const Color(0xFF1A1B20),
          surfaceContainerLow: const Color(0xFF1A1B20),
          surfaceContainer: const Color(0xFF1A1B20),
          surfaceContainerHigh: const Color(0xFF1A1B20),
          surfaceContainerHighest: const Color(0xFF1A1B20),
        );

    final repaired = PixelPlayTheme.dark(
      scheme: incompleteDynamicScheme,
    ).colorScheme;

    expect(repaired.surfaceContainerLowest, isNot(repaired.surfaceContainer));
    expect(repaired.surfaceContainerLow, isNot(repaired.surfaceContainer));
    expect(repaired.surfaceContainerHigh, isNot(repaired.surfaceContainer));
    expect(
      repaired.surfaceContainerHighest,
      isNot(repaired.surfaceContainerHigh),
    );
    expect(
      repaired.surfaceContainerLowest.computeLuminance(),
      lessThan(repaired.surfaceContainer.computeLuminance()),
    );
    expect(
      repaired.surfaceContainer.computeLuminance(),
      lessThan(repaired.surfaceContainerHighest.computeLuminance()),
    );
  });

  test('genre colors use the same normalized JVM hash as Kotlin', () {
    final funk = GenreTheme.reference('Funk', brightness: Brightness.dark);

    expect(funk.container, const Color(0xFF93000A));
    expect(funk.onContainer, const Color(0xFFFFDAD6));
    expect(
      GenreTheme.reference('funk', brightness: Brightness.dark).container,
      funk.container,
    );
  });

  test('dismiss undo restores the song, queue, and playback position', () {
    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    controller.playSong(
      MockLibrary.songs.first,
      fromQueue: MockLibrary.songs.take(3).toList(),
    );
    controller.seek(.5);
    controller.togglePlayPause();
    final savedPosition = controller.position;

    expect(controller.dismissPlaylist(), isTrue);
    expect(controller.currentSong, isNull);
    expect(controller.queue, isEmpty);
    expect(controller.showDismissUndoBar, isTrue);

    expect(controller.undoDismissPlaylist(), isTrue);
    controller.togglePlayPause();
    expect(controller.currentSong?.id, MockLibrary.songs.first.id);
    expect(controller.queue.length, 3);
    expect(controller.position, savedPosition);
    expect(controller.showDismissUndoBar, isFalse);
  });

  test(
    'artist parsing handles punctuation delimiters and names each group',
    () {
      final controller = AppController(setupComplete: true);
      addTearDown(controller.dispose);
      controller
        ..setStringListSetting('artist_character_delimiters', const [';'])
        ..setStringListSetting('artist_word_delimiters', const [
          'feat.',
          'with',
        ])
        ..songs = const [
          Song(
            id: 'collaboration',
            title: 'Collaboration',
            artist: 'Luna Vale feat. Aria Bloom; Mira June',
            album: 'Singles',
            genre: 'Pop',
            duration: Duration(minutes: 3),
            colors: [Colors.purple, Colors.pink],
          ),
        ];

      expect(
        controller.splitArtistNames(
          'Luna Vale feat. Aria Bloom; Mira June with Nova Arcade',
        ),
        const ['Luna Vale', 'Aria Bloom', 'Mira June', 'Nova Arcade'],
      );
      expect(controller.artists.map((artist) => artist.name), const [
        'Luna Vale',
        'Aria Bloom',
        'Mira June',
      ]);
    },
  );

  test('playback position only notifies its lightweight listener', () {
    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    var globalNotifications = 0;
    var positionNotifications = 0;
    controller.addListener(() => globalNotifications++);
    controller.positionListenable.addListener(() => positionNotifications++);

    controller.position = const Duration(seconds: 12);

    expect(controller.position, const Duration(seconds: 12));
    expect(positionNotifications, 1);
    expect(globalNotifications, 0);
  });

  testWidgets('shows the original PixelPlay setup gate', (tester) async {
    await tester.pumpWidget(const PixelPlayApp(platformServicesEnabled: false));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('to'), findsOneWidget);
    expect(find.text('PixelPlayer'), findsOneWidget);
    expect(find.text("Let's Go!"), findsOneWidget);
  });

  testWidgets('shows the primary PixelPlay navigation after setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      const PixelPlayApp(skipSetup: true, platformServicesEnabled: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your music will appear here'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);

    await tester.tap(find.text('Library'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<AppScope>(find.byType(AppScope)).notifier!.selectedTab,
      2,
    );
    expect(find.text('No songs yet'), findsOneWidget);
  });

  testWidgets('setup fits a compact phone and reaches the app shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PixelPlayApp(platformServicesEnabled: false));
    await tester.pump(const Duration(milliseconds: 400));

    for (var page = 0; page < 10; page++) {
      tester.widget<InkWell>(find.byKey(const ValueKey('setup-next'))).onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(
      find.byKey(const ValueKey('finish')),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .join(' | '),
    );
    tester.widget<InkWell>(find.byKey(const ValueKey('setup-next'))).onTap!();
    await tester.pumpAndSettle();
    expect(find.text('Your music will appear here'), findsOneWidget);
  });

  testWidgets('expanded player fits a compact phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    controller.playSong(MockLibrary.songs.first);
    controller.togglePlayPause();
    controller.showFullPlayer();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('Afterglow'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a light vertical drag does not dismiss the full player', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    controller
      ..playSong(MockLibrary.songs.first)
      ..togglePlayPause()
      ..showFullPlayer();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.drag(
      find.byKey(const ValueKey('full-player-drag-surface')),
      const Offset(0, 20),
    );
    await tester.pump();

    expect(controller.fullPlayerVisible, isTrue);
    expect(find.text('Now Playing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded player follows a drag and springs back like Kotlin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    controller
      ..playSong(MockLibrary.songs.first)
      ..togglePlayPause()
      ..showFullPlayer();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final surface = find.byKey(const ValueKey('full-player-drag-surface'));
    final gesture = await tester.startGesture(tester.getCenter(surface));
    await gesture.moveBy(const Offset(0, 32));
    await tester.pump();

    expect(controller.fullPlayerDragOffset.value, closeTo(32, .01));
    expect(controller.fullPlayerVisible, isTrue);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(controller.fullPlayerDragOffset.value, 0);
    expect(controller.fullPlayerVisible, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded player adapts to landscape and reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    controller
      ..playSong(MockLibrary.songs.first)
      ..togglePlayPause()
      ..showFullPlayer();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('landscape-player')), findsOneWidget);
    expect(find.text('Now Playing'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('player-landscape-lyrics'))),
      const Size(50, 42),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('player-landscape-queue'))),
      const Size(50, 42),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('player sheets add Kotlin depth without exposing a black edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 837);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    controller
      ..playSong(MockLibrary.songs.first)
      ..togglePlayPause()
      ..showFullPlayer();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    AnimatedScale playerDepth() => tester.widget<AnimatedScale>(
      find.byKey(const ValueKey('full-player-sheet-depth')),
    );

    expect(playerDepth().scale, 1);
    await tester.tap(find.bySemanticsLabel('Audio output'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Connect device'), findsOneWidget);
    expect(playerDepth().scale, .972);
    expect(playerDepth().duration, const Duration(milliseconds: 220));
    expect(playerDepth().curve, Curves.fastOutSlowIn);

    Navigator.of(tester.element(find.text('Connect device'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Connect device'), findsNothing);
    expect(playerDepth().scale, 1);

    await tester.tap(find.bySemanticsLabel('Open queue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Next up'), findsOneWidget);
    expect(playerDepth().scale, .972);
    expect(find.byKey(const ValueKey('queue-sheet-handle')), findsOneWidget);
    final depthBackground = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('full-player-depth-background')),
    );
    expect(depthBackground.color, isNot(Colors.black));

    Navigator.of(tester.element(find.text('Next up'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(playerDepth().scale, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('One Peek carousel uses the Kotlin start alignment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 837);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..setStringSetting('carousel_style', 'One Peek');
    addTearDown(controller.dispose);
    controller
      ..playSong(
        MockLibrary.songs.first,
        fromQueue: MockLibrary.songs.take(3).toList(),
      )
      ..togglePlayPause()
      ..showFullPlayer();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final carousel = tester.widget<PageView>(find.byType(PageView));
    expect(carousel.padEnds, isFalse);
    expect(carousel.controller!.viewportFraction, closeTo(.8, .001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait player keeps Kotlin source geometry', (tester) async {
    tester.view.physicalSize = const Size(393, 837);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    controller
      ..playSong(
        MockLibrary.songs.first,
        fromQueue: MockLibrary.songs.take(3).toList(),
      )
      ..togglePlayPause()
      ..showFullPlayer();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    final album = tester.getRect(
      find.byKey(const ValueKey('player-album-carousel')),
    );
    expect(album.left, closeTo(24, .01));
    expect(album.width, closeTo(345, .01));
    expect(album.height, closeTo(345, .01));

    expect(
      tester.getSize(find.byKey(const ValueKey('player-song-metadata'))),
      const Size(345, 70),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('player-progress'))),
      const Size(345, 70),
    );
    final progressSliderFinder = find.byKey(
      const ValueKey('player-progress-slider'),
    );
    expect(tester.getSize(progressSliderFinder), const Size(345, 24));
    final progressSlider = tester.widget<WavySlider>(progressSliderFinder);
    expect(progressSlider.strokeWidth, 5);
    expect(progressSlider.thumbRadius, 8);
    expect(progressSlider.trackEdgePadding, 0);
    expect(progressSlider.wavelength, 40);
    expect(progressSlider.waveAmplitude, 4);
    expect(
      tester.getSize(find.byKey(const ValueKey('player-transport-controls'))),
      const Size(321, 80),
    );

    final toggles = tester.getRect(
      find.byKey(const ValueKey('player-bottom-toggles')),
    );
    expect(toggles.left, closeTo(50, .01));
    expect(toggles.width, closeTo(293, .01));
    expect(toggles.height, closeTo(66, .01));
    expect(837 - toggles.bottom, greaterThanOrEqualTo(20));

    final toggleContainer = tester.getRect(
      find.byKey(const ValueKey('player-toggle-container')),
    );
    final shuffle = tester.getRect(
      find.byKey(const ValueKey('player-toggle-shuffle')),
    );
    final repeat = tester.getRect(
      find.byKey(const ValueKey('player-toggle-repeat')),
    );
    final favorite = tester.getRect(
      find.byKey(const ValueKey('player-toggle-favorite')),
    );
    expect(toggleContainer, toggles);
    expect(shuffle.left, toggles.left + 6);
    expect(shuffle.top, toggles.top + 6);
    expect(shuffle.height, 54);
    expect(repeat.left, closeTo(shuffle.right + 6, .001));
    expect(favorite.left, closeTo(repeat.right + 6, .001));
    expect(favorite.right, closeTo(toggles.right - 6, .001));

    final toggleColors = Theme.of(
      tester.element(find.byKey(const ValueKey('player-toggle-container'))),
    ).colorScheme;
    final toggleDecoration =
        tester
                .widget<Container>(
                  find.byKey(const ValueKey('player-toggle-container')),
                )
                .decoration
            as ShapeDecoration;
    expect(
      toggleDecoration.color,
      toggleColors.surfaceContainerLowest.withValues(alpha: .7),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait tablet keeps Kotlin width-derived artwork size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    controller
      ..playSong(
        MockLibrary.songs.first,
        fromQueue: MockLibrary.songs.take(3).toList(),
      )
      ..togglePlayPause()
      ..showFullPlayer();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      tester.getSize(find.byKey(const ValueKey('player-album-carousel'))),
      const Size.square(652),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('queue sheet mirrors Kotlin header rows and floating toolbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 837);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final queue = MockLibrary.songs.take(3).toList();
    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    controller
      ..playSong(queue.first, fromQueue: queue)
      ..togglePlayPause()
      ..showFullPlayer();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.bySemanticsLabel('Open queue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('queue-sheet')), findsOneWidget);
    expect(find.text('Next up'), findsOneWidget);
    expect(find.text('3 tracks lined up'), findsOneWidget);
    expect(find.text('Current queue'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('queue-bottom-toolbar'))),
      const Size(266, 70),
    );
    expect(
      find.byIcon(Icons.drag_indicator_rounded),
      findsNWidgets(queue.length - 1),
    );

    final currentCard = tester.widget<Material>(
      find.byKey(ValueKey('queue-song-${queue.first.id}-0')),
    );
    expect(currentCard.borderRadius, BorderRadius.circular(60));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cast sheet keeps Kotlin controls geometry on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 837);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    controller.playSong(MockLibrary.songs.first);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showCastBottomSheet(
                    context: context,
                    song: controller.currentSong,
                  ),
                  child: const Text('Open output'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open output'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Connect device'), findsOneWidget);
    final sheetTitle = tester.widget<Text>(
      find.byKey(const ValueKey('cast-sheet-title')),
    );
    final sheetTitleRect = tester.getRect(
      find.byKey(const ValueKey('cast-sheet-title')),
    );
    final sheetHandleRect = tester.getRect(
      find.byKey(const ValueKey('cast-sheet-handle')),
    );
    expect(sheetTitle.style?.fontWeight, FontWeight.w400);
    expect(sheetTitleRect.left, 26);
    expect(sheetHandleRect.size, const Size(32, 4));
    expect(sheetHandleRect.center.dx, 393 / 2);
    expect(sheetHandleRect.bottom, lessThan(sheetTitleRect.top));
    final firstSheetPrimary = Theme.of(
      tester.element(find.text('Connect device')),
    ).colorScheme.primary;
    expect(find.text('CONTROLS'), findsOneWidget);
    expect(find.text('DEVICES'), findsOneWidget);
    expect(tester.getSize(find.byType(PageView)), const Size(393, 313));
    expect(find.text('Scanning nearby'), findsOneWidget);
    expect(find.text('Nearby devices'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cast-scanning-progress')),
      findsOneWidget,
    );
    for (var index = 0; index < 3; index++) {
      expect(
        tester.getSize(
          find.byKey(ValueKey('cast-scanning-placeholder-$index')),
        ),
        const Size(353, 68),
      );
    }

    await tester.tap(find.text('CONTROLS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('This phone'), findsOneWidget);
    expect(find.text('Phone volume'), findsOneWidget);
    expect(tester.getSize(find.byType(PageView)), const Size(393, 340));

    await tester.tap(find.text('DEVICES'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Nearby devices'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Scanning nearby'), findsNothing);
    expect(find.byKey(const ValueKey('cast-scanning-progress')), findsNothing);
    expect(tester.getSize(find.byType(PageView)), const Size(393, 248));

    controller.playSong(MockLibrary.songs[1]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final nextSheetPrimary = Theme.of(
      tester.element(find.text('Connect device')),
    ).colorScheme.primary;
    expect(nextSheetPrimary, isNot(firstSheetPrimary));
    if (controller.isPlaying) controller.togglePlayPause();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sleep timer keeps the Kotlin dual-slider expressive layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 837);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..setSleepAfterTracks(3);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () =>
                      showSleepTimerBottomSheet(context, controller),
                  child: const Text('Open timer'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open timer'));
    await tester.pumpAndSettle();

    expect(find.text('Sleep timer'), findsOneWidget);
    expect(find.text('Timer: Off'), findsOneWidget);
    expect(find.text('Play count: 3 times'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(2));
    expect(find.text('End of current track'), findsOneWidget);
    expect(find.text('Custom time'), findsOneWidget);
    expect(find.text('Cancel timer'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Custom time')),
      const Size(175.5, 68),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('song information uses Kotlin actions and metadata pages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 837);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    final song = MockLibrary.songs.first;
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () =>
                      showSongInfoBottomSheet(context: context, song: song),
                  child: const Text('Open song info'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open song info'));
    await tester.pumpAndSettle();

    expect(find.text(song.title), findsOneWidget);
    expect(find.text('Add to queue'), findsOneWidget);
    expect(find.text('Play next'), findsOneWidget);
    expect(find.text('Options'), findsOneWidget);
    expect(find.text('Info'), findsOneWidget);

    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Audio format'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('queue removal supports undo and clear-except-current', () {
    final queue = MockLibrary.songs.take(3).toList();
    final controller = AppController(setupComplete: true)
      ..playSong(queue.first, fromQueue: queue);
    addTearDown(controller.dispose);

    expect(controller.removeSongFromQueue(queue[1].id), isTrue);
    expect(controller.queue.map((song) => song.id), [queue[0].id, queue[2].id]);
    expect(controller.undoRemoveSongFromQueue(), isTrue);
    expect(
      controller.queue.map((song) => song.id),
      queue.map((song) => song.id),
    );

    controller.clearQueueExceptCurrent();
    expect(controller.queue, [queue.first]);
    expect(controller.currentSong, queue.first);
  });

  test('counted sleep mode tracks the selected remaining songs', () {
    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);

    controller.setSleepAfterTracks(4);
    expect(controller.sleepTracksRemaining, 4);
    expect(controller.sleepTimerLabel, '4 tracks');

    controller.setSleepAfterTracks(1);
    expect(controller.sleepTracksRemaining, isNull);
    expect(controller.sleepTimerLabel, isNull);
  });

  testWidgets('mini player controls keep 44dp touch targets', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    controller.playSong(MockLibrary.songs.first);
    controller.togglePlayPause();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    for (final label in const ['Anterior', 'Reproducir', 'Siguiente']) {
      final bounds = tester.getRect(find.bySemanticsLabel(label).last);
      expect(bounds.width, greaterThanOrEqualTo(44));
      expect(bounds.height, greaterThanOrEqualTo(44));
    }

    await tester.tap(find.byKey(const ValueKey('mini-player')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.fullPlayerVisible, isTrue);
    expect(find.text('Now Playing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Daily Mix adapts its header on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..songs = MockLibrary.songs
      ..libraryLoading = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: DailyMixScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Daily Mix'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('daily-mix-header'))).height,
      340,
    );
    expect(find.byKey(const ValueKey('daily-mix-back')), findsOneWidget);
    expect(find.text('Play it'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('genre list keeps the Kotlin fixed 100dp card height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..setBoolSetting('search_genre_grid', false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: Scaffold(
            body: GenreCategoriesGrid(
              genres: const ['Alternative', 'Dream Pop'],
              selectedGenres: const [],
              onGenreClick: (_) {},
              onSelectionToggle: (_) {},
              onSelectAll: () {},
              onClearSelection: () {},
              onSelectionOptions: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Browse by genre'), findsOneWidget);
    expect(tester.getSize(find.byType(Card).first).height, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search uses the Kotlin bar and vertical media result cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 837);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..songs = MockLibrary.songs
      ..libraryLoading = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: Scaffold(
            body: SearchScreen(
              onOpenAlbum: (_) {},
              onOpenArtist: (_) {},
              onOpenPlaylist: (_) {},
              onOpenGenre: (_) {},
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.getSize(find.byType(SearchBar)).height, 56);
    expect(find.text('Browse by genre'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'Luna');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Albums'), findsWidgets);
    expect(find.text('Artists'), findsWidgets);
    expect(find.byType(SearchResultMediaCard), findsWidgets);
    expect(tester.getSize(find.byType(SearchResultMediaCard).first).height, 80);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search fits landscape with reduced motion and 1.3x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..songs = MockLibrary.songs
      ..libraryLoading = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SearchScreen(
              onOpenAlbum: (_) {},
              onOpenArtist: (_) {},
              onOpenPlaylist: (_) {},
              onOpenGenre: (_) {},
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(SearchBar), 'Luna');
    await tester.pumpAndSettle();

    expect(find.text('Afterglow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
