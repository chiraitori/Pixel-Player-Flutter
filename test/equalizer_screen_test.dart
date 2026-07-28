import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/equalizer/equalizer_screen.dart';
import 'package:pixelplayer_flutter/features/player/mini_player.dart';

import 'fixtures/mock_library.dart';

void main() {
  testWidgets('Equalizer keeps the Kotlin collapsible expressive shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    controller.currentSong = MockLibrary.songs.first;
    controller.queue = MockLibrary.songs;
    controller.notifyListeners();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: EqualizerScreen()),
      ),
    );
    await tester.pump();

    expect(
      tester
          .getSize(find.byKey(const ValueKey('equalizer-collapsible-header')))
          .height,
      180,
    );
    expect(find.byType(MiniPlayer), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('equalizer-view-mode-button')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('equalizer-response-graph')),
      findsOneWidget,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pump();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('equalizer-collapsible-header')))
          .height,
      64,
    );
    expect(tester.takeException(), isNull);
  });
}
