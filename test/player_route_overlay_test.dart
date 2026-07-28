import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/player/mini_player.dart';
import 'package:pixelplayer_flutter/features/shell/player_route_overlay.dart';

import 'fixtures/mock_library.dart';

void main() {
  testWidgets('pushed routes retain Kotlin unified player behavior', (
    tester,
  ) async {
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
        child: const MaterialApp(
          home: PlayerRouteOverlay(
            child: Scaffold(body: Center(child: Text('Child route'))),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Child route'), findsOneWidget);
    expect(find.byType(MiniPlayer), findsOneWidget);

    await tester.tap(find.byType(MiniPlayer));
    await tester.pump();
    expect(controller.fullPlayerVisible, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(controller.fullPlayerVisible, isFalse);
    expect(find.text('Child route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
