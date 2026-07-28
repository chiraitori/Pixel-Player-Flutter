import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/accounts/navidrome_dashboard_screen.dart';

void main() {
  testWidgets(
    'Navidrome dashboard keeps Kotlin dashboard actions without credentials',
    (tester) async {
      final controller = AppController(setupComplete: true);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: const MaterialApp(home: NavidromeDashboardScreen()),
        ),
      );
      await tester.pump();

    expect(find.text('Subsonic'), findsWidgets);
      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.text('Sync library'), findsOneWidget);
      expect(find.text('Connect a Subsonic server first.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
