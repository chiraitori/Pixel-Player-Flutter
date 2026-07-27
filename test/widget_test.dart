import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/app.dart';
import 'package:pixelplayer_flutter/core/models/song.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/core/theme/genre_theme.dart';
import 'package:pixelplayer_flutter/core/theme/pixelplay_theme.dart';
import 'package:pixelplayer_flutter/features/home/daily_mix_screen.dart';
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

    expect(find.text('DAILY\nMIX'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
