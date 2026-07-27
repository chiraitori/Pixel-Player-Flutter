import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/library/library_screen.dart';

import 'fixtures/mock_library.dart';

void main() {
  testWidgets('compact Library matches the Kotlin action hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..songs = MockLibrary.songs
      ..libraryLoading = false
      ..libraryCompactMode = true;
    addTearDown(controller.dispose);
    controller.playSong(MockLibrary.songs.last, fromQueue: MockLibrary.songs);
    controller.togglePlayPause();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: Scaffold(
            body: LibraryScreen(
              onOpenSettings: () {},
              onOpenAlbum: (_) {},
              onOpenArtist: (_) {},
              onOpenPlaylist: (_) {},
              onOpenGenre: (_) {},
              onCreatePlaylist: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Songs'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('library-section-segment')))
          .height,
      52,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('library-section-arrow-segment')))
          .height,
      52,
    );
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.byIcon(Icons.dataset_rounded), findsOneWidget);
    expect(find.byIcon(Icons.sort_rounded), findsOneWidget);
    expect(find.text(MockLibrary.songs.first.title), findsOneWidget);
    expect(find.text(MockLibrary.songs.first.artist), findsWidgets);
    expect(LibrarySection.values.map((section) => section.label), const [
      'Songs',
      'Albums',
      'Artists',
      'Playlists',
      'Folders',
      'Liked',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('album long press enters Kotlin-style media selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..songs = MockLibrary.songs
      ..libraryLoading = false
      ..libraryCompactMode = true;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: Scaffold(
            body: LibraryScreen(
              onOpenSettings: () {},
              onOpenAlbum: (_) {},
              onOpenArtist: (_) {},
              onOpenPlaylist: (_) {},
              onOpenGenre: (_) {},
              onCreatePlaylist: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('library-section-segment')));
    await tester.pumpAndSettle();
    expect(find.text('Genres'), findsNothing);
    expect(find.text('Liked'), findsOneWidget);
    await tester.tap(find.text('Albums').last);
    await tester.pumpAndSettle();

    expect(find.text('Albums'), findsOneWidget);
    await tester.longPress(find.text('Neon Weather'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byIcon(Icons.select_all_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('album Grid and List controls live in the Kotlin sort sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..songs = MockLibrary.songs
      ..libraryLoading = false
      ..libraryCompactMode = true;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: Scaffold(
            body: LibraryScreen(
              onOpenSettings: () {},
              onOpenAlbum: (_) {},
              onOpenArtist: (_) {},
              onOpenPlaylist: (_) {},
              onOpenGenre: (_) {},
              onCreatePlaylist: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SegmentedButton<bool>), findsNothing);
    await tester.tap(find.byKey(const ValueKey('library-section-segment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Albums').last);
    await tester.pumpAndSettle();

    expect(find.text('${MockLibrary.albums.length} albums'), findsNothing);
    await tester.tap(find.byIcon(Icons.sort_rounded));
    await tester.pumpAndSettle();

    expect(find.text('View'), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact Library fits landscape with reduced motion and 1.3x text',
    (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = AppController(setupComplete: true)
        ..songs = MockLibrary.songs
        ..libraryLoading = false
        ..libraryCompactMode = true;
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
              body: LibraryScreen(
                onOpenSettings: () {},
                onOpenAlbum: (_) {},
                onOpenArtist: (_) {},
                onOpenPlaylist: (_) {},
                onOpenGenre: (_) {},
                onCreatePlaylist: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Songs'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
