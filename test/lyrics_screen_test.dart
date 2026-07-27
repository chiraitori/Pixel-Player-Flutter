import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/data/lyrics_parser.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/player/lyrics_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/mock_library.dart';

void main() {
  testWidgets('missing lyrics opens the compact Pick up flow', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    final song = MockLibrary.songs.first;
    controller.playSong(song);
    controller.togglePlayPause();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showLyricsFlow(context, song),
                  child: const Text('Lyrics'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Lyrics'));
    await tester.pumpAndSettle();

    expect(
      find.text('Would you like to search for lyrics online?'),
      findsOneWidget,
    );
    expect(find.text('Show lyric options'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('lyrics-rounded-star'))),
      const Size.square(72),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('synced and static lyrics fit a compact phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    final song = MockLibrary.songs.first;
    controller.playSong(song);
    controller.togglePlayPause();
    controller.position = const Duration(seconds: 7);
    final lyrics = LyricsParser.parse('''
[00:01.00]When the hands that shaped the horizon
[00:05.00]The world was only just a dream
[00:10.00]When the first light shattered the silence
''');

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: LyricsScreen(song: song, initialLyrics: lyrics),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Synced'), findsOneWidget);
    expect(find.text('Static'), findsOneWidget);
    expect(find.text('The world was only just a dream'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lyrics options expose Kotlin sync and appearance controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    final song = MockLibrary.songs.first;
    final lyrics = LyricsParser.parse(
      '[00:01.00]<00:01.00>Hello <00:01.50>world',
    );

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: LyricsScreen(song: song, initialLyrics: lyrics),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Save lyrics'), findsOneWidget);
    expect(find.text('Adjust synchronization'), findsOneWidget);
    expect(find.byIcon(Icons.format_align_center_rounded), findsOneWidget);
    expect(find.text('Keep screen on'), findsOneWidget);

    await tester.tap(find.text('Adjust synchronization'));
    await tester.pump();
    expect(find.text('−.5'), findsOneWidget);
    expect(find.text('+.5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
