import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/playback/edit_transition_screen.dart';

void main() {
  testWidgets('global transition editor mirrors Kotlin and persists mode', (
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
        child: const MaterialApp(home: EditTransitionScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Playback transitions'), findsWidgets);
    expect(
      find.byKey(const ValueKey('transition-summary-card')),
      findsOneWidget,
    );
    expect(find.text('Global default'), findsOneWidget);
    expect(find.text('Custom override'), findsNothing);
    expect(
      find.byKey(const ValueKey('transition-duration-card')),
      findsOneWidget,
    );

    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('transition-details-hidden')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('transition-save')));
    await tester.pump();
    expect(controller.boolSetting('playback_crossfade_enabled', true), isFalse);
    expect(find.text('Transition settings saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playlist transition editor exposes source-only override', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..setStringSetting('transition_playlist_id', 'playlist-7');
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
          home: const EditTransitionScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Playlist transition rules'), findsWidgets);
    expect(find.text('Custom override'), findsOneWidget);
    await tester.ensureVisible(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('transition-save')));
    await tester.pump();

    expect(
      controller.boolSetting('transition_playlist_playlist-7_override', false),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
