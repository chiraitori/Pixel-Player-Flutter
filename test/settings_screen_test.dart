import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/player/mini_player.dart';
import 'package:pixelplayer_flutter/features/settings/settings_screen.dart';

import 'fixtures/mock_library.dart';

void main() {
  testWidgets(
    'Settings keeps the Kotlin player overlay above its grouped rows',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = AppController(setupComplete: true)
        ..currentSong = MockLibrary.songs.first
        ..queue = MockLibrary.songs;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            home: SettingsScreen(
              onBack: () {},
              onOpenCategory: (_) {},
              onOpenAccounts: () {},
              onOpenAbout: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Music Management'), findsOneWidget);
      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
