import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/library/widgets/tab_animation.dart';
import 'package:pixelplayer_flutter/features/stats/stats_screen.dart';

void main() {
  testWidgets('Stats uses Kotlin Week tabs and equal expressive hero cards', (
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
        child: const MaterialApp(home: StatsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final tabs = tester.widgetList<TabAnimation>(find.byType(TabAnimation));
    final rangeList = tester.widget<ListView>(
      find.byKey(const ValueKey('stats-range-tabs')),
    );
    expect(rangeList.childrenDelegate.estimatedChildCount, 5);
    expect(tabs.every((tab) => tab.selectedIndex == 1), isTrue);
    expect(find.text('Listening'), findsOneWidget);
    expect(find.text('Plays'), findsOneWidget);
    expect(find.text('--'), findsNWidgets(2));

    final listening = tester.getSize(
      find.byKey(const ValueKey('stats-listening-hero')),
    );
    final plays = tester.getSize(
      find.byKey(const ValueKey('stats-plays-hero')),
    );
    expect(listening.width, closeTo(plays.width, .01));
    expect(listening.height, closeTo(plays.height, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Stats fits landscape with reduced motion and 1.3x text', (
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
          home: const StatsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Listening stats'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
