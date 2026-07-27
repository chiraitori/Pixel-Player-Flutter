import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/accounts/google_drive_connect_screen.dart';

void main() {
  testWidgets('Drive setup explains and validates OAuth configuration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: const MaterialApp(home: GoogleDriveConnectScreen()),
      ),
    );

    expect(find.text('Google Drive'), findsOneWidget);
    expect(find.text('OAuth Web client ID'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'not-a-google-client-id');
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a valid Google OAuth Web client ID.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
