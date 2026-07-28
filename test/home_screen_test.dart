import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/home/home_screen.dart';

import 'fixtures/mock_library.dart';

void main() {
  testWidgets('Home keeps the Kotlin expressive hero and collage geometry', (
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

    await tester.pumpWidget(_home(controller));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey('home-beta')), findsOneWidget);
    expect(find.text('Your\nMix'), findsOneWidget);
    final yourMixTitle = tester.widget<Text>(find.text('Your\nMix'));
    expect(
      yourMixTitle.style?.fontVariations,
      contains(const ui.FontVariation('wdth', 152)),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('home-your-mix-header'))).height,
      256,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('home-album-art-collage')))
          .height,
      400,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('home-shuffle-play'))),
      const Size(96, 96),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home sections remain usable in landscape with reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 393);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..songs = MockLibrary.songs
      ..libraryLoading = false;
    addTearDown(controller.dispose);
    for (final song in MockLibrary.songs.take(5)) {
      controller.playSong(song, fromQueue: MockLibrary.songs);
    }
    controller.dismissPlaylist();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 393),
          disableAnimations: true,
          textScaler: TextScaler.linear(1.3),
        ),
        child: _home(controller),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('home-daily-mix-section')),
      findsOneWidget,
    );
    expect(find.text('DAILY MIX'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });
}

Widget _home(AppController controller) {
  return AppScope(
    controller: controller,
    child: MaterialApp(
      home: Scaffold(
        body: HomeScreen(
          onOpenSettings: () {},
          onOpenDailyMix: () {},
          onOpenRecentlyPlayed: () {},
          onOpenStats: () {},
          onOpenAlbum: (_) {},
          onOpenAccounts: () {},
        ),
      ),
    ),
  );
}
