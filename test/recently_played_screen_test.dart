import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/home/recently_played_screen.dart';

import 'fixtures/mock_library.dart';

void main() {
  testWidgets(
    'Recently Played mirrors the Kotlin expressive header and actions',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = AppController(setupComplete: true)
        ..songs = MockLibrary.songs
        ..playSong(MockLibrary.songs.first, fromQueue: MockLibrary.songs);

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: const MaterialApp(home: RecentlyPlayedScreen()),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byKey(const ValueKey('recently-played-header'))),
        const Size(360, 190),
      );
      expect(
        find.byKey(const ValueKey('recently-played-back')),
        findsOneWidget,
      );
      expect(find.text('Week to Date'), findsOneWidget);
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('recent-history-range-Week to Date')),
            )
            .height,
        44,
      );
      expect(find.text('Play latest'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(
        tester.getSize(find.widgetWithText(FilledButton, 'Play latest')).height,
        52,
      );
      expect(find.text('Today'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('Recently Played empty state fits reduced-motion landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
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
          home: const RecentlyPlayedScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Nothing played week to date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
