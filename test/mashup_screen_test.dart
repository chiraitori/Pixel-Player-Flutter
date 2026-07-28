import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/mashup/mashup_screen.dart';

import 'fixtures/mock_library.dart';

void main() {
  testWidgets(
    'Mashup keeps Kotlin two-deck order and live transport controls',
    (tester) async {
      final controller = AppController(setupComplete: true)
        ..songs = MockLibrary.songs;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: const MaterialApp(home: MashupScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Mashup'), findsOneWidget);
    expect(find.text('Deck 1'), findsOneWidget);
    expect(find.text('Deck 2'), findsOneWidget);
    final crossfader = find.text('Crossfader', skipOffstage: false);
    expect(crossfader, findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Deck 1').first).dy,
        lessThan(tester.getTopLeft(find.text('Deck 2').first).dy),
      );
      expect(
        tester.getTopLeft(find.text('Deck 2').first).dy,
      lessThan(tester.getTopLeft(crossfader).dy),
      );
    expect(find.text('<<', skipOffstage: false), findsNWidgets(2));
    expect(find.text('>>', skipOffstage: false), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
