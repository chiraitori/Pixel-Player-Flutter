import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/data/lyrics_parser.dart';
import 'package:pixelplayer_flutter/core/models/lyrics.dart';
import 'package:pixelplayer_flutter/core/models/song.dart';
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

  testWidgets('an open lyrics screen safely shows an empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    final song = MockLibrary.songs.first;

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: LyricsScreen(
            song: song,
            initialLyrics: const LyricsDocument(raw: ''),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No lyrics available'), findsOneWidget);
    expect(find.text('This track does not have lyrics yet.'), findsOneWidget);
    expect(find.text('Search or import lyrics'), findsOneWidget);
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

    final play = tester.getRect(
      find.byKey(const ValueKey('lyrics-play-pause')),
    );
    final seek = tester.getRect(
      find.byKey(const ValueKey('lyrics-seek-container')),
    );
    final toolbar = tester.getRect(
      find.byKey(const ValueKey('lyrics-floating-toolbar')),
    );
    final back = tester.getRect(
      find.byKey(const ValueKey('lyrics-back-button')),
    );
    final synced = tester.getRect(
      find.byKey(const ValueKey('lyrics-synced-button')),
    );
    final staticMode = tester.getRect(
      find.byKey(const ValueKey('lyrics-static-button')),
    );
    final more = tester.getRect(
      find.byKey(const ValueKey('lyrics-more-button')),
    );

    expect(play.left, 16);
    expect(play.size, const Size.square(78));
    expect(seek.left, play.right + 12);
    expect(seek.right, 344);
    expect(seek.height, 50);
    expect(seek.center.dy, play.center.dy);
    expect(toolbar.top, play.bottom + 16);
    expect(back.left, 16);
    expect(back.size, const Size.square(48));
    expect(synced.left, back.right + 8);
    expect(synced.height, 50);
    expect(staticMode.left, synced.right + 8);
    expect(staticMode.height, 50);
    expect(more.left, staticMode.right + 8);
    expect(more.right, 344);
    expect(more.size, const Size.square(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('open lyrics follows the live queue song and its timestamps', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lyrics_content_lyrics-switch-second':
          '[00:02.00]Second song first line\n'
          '[00:06.00]Second song active line',
    });
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const first = Song(
      id: 'lyrics-switch-first',
      title: 'First Track',
      artist: 'First Artist',
      album: 'Switch Test',
      genre: 'Test',
      duration: Duration(minutes: 3),
      colors: <Color>[Color(0xFF654A86), Color(0xFFAF82C7)],
    );
    const second = Song(
      id: 'lyrics-switch-second',
      title: 'Second Track',
      artist: 'Second Artist',
      album: 'Switch Test',
      genre: 'Test',
      duration: Duration(minutes: 3),
      colors: <Color>[Color(0xFF3F5687), Color(0xFF9DB4E8)],
    );
    final controller = AppController(setupComplete: true);
    addTearDown(controller.dispose);
    controller.playSong(first, fromQueue: const <Song>[first, second]);
    controller.togglePlayPause();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: LyricsScreen(
            song: first,
            initialLyrics: LyricsParser.parse('[00:01.00]First song lyric'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('First Track'), findsOneWidget);
    expect(find.text('First song lyric'), findsOneWidget);
    final firstScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(
      firstScaffold.backgroundColor,
      ColorScheme.fromSeed(
        seedColor: first.colors.first,
        dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      ).primaryContainer,
    );

    controller.playSong(second, fromQueue: const <Song>[first, second]);
    controller.togglePlayPause();
    controller.position = const Duration(seconds: 7);
    controller.notifyListeners();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Second Track'), findsOneWidget);
    expect(find.text('Second song active line'), findsOneWidget);
    expect(find.text('First song lyric'), findsNothing);
    final secondScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(
      secondScaffold.backgroundColor,
      ColorScheme.fromSeed(
        seedColor: second.colors.first,
        dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      ).primaryContainer,
    );
    expect(
      secondScaffold.backgroundColor,
      isNot(firstScaffold.backgroundColor),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a horizontal lyrics swipe changes track and Material You palette',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'lyrics_content_lyrics-swipe-second': '[00:01.00]Second swipe lyric',
      });
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const first = Song(
        id: 'lyrics-swipe-first',
        title: 'First swipe track',
        artist: 'First Artist',
        album: 'Swipe Test',
        genre: 'Test',
        duration: Duration(minutes: 3),
        colors: <Color>[Color(0xFF9B3E3E)],
      );
      const second = Song(
        id: 'lyrics-swipe-second',
        title: 'Second swipe track',
        artist: 'Second Artist',
        album: 'Swipe Test',
        genre: 'Test',
        duration: Duration(minutes: 3),
        colors: <Color>[Color(0xFF275EAA)],
      );
      final controller = AppController(setupComplete: true);
      addTearDown(controller.dispose);
      controller.playSong(first, fromQueue: const <Song>[first, second]);

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            home: LyricsScreen(
              song: first,
              initialLyrics: LyricsParser.parse('[00:01.00]First swipe lyric'),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('lyrics-scroll-view')),
        const Offset(-112, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(controller.currentSong?.id, second.id);
      expect(find.text('Second swipe track'), findsOneWidget);
      expect(find.text('Second swipe lyric'), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        ColorScheme.fromSeed(
          seedColor: second.colors.first,
          dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
        ).primaryContainer,
      );
      if (controller.isPlaying) controller.togglePlayPause();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('active lyric is aligned to the Kotlin highlight centre', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..setBoolSetting('immersive_lyrics', true);
    addTearDown(controller.dispose);
    final song = MockLibrary.songs.first;
    controller.position = const Duration(seconds: 31);
    final lyrics = LyricsParser.parse('''
[00:01.00]A short opening line
[00:05.00]This intentionally long lyric wraps over more than one visual line on a compact phone
[00:10.00]Another line
[00:15.00]The fourth line is also deliberately long enough to have a different measured height
[00:20.00]Fifth
[00:25.00]Sixth line with medium length
[00:30.00]This active seventh lyric must use its real RenderBox centre
[00:35.00]Eighth
[00:40.00]Ninth line after active
[00:45.00]Tenth line after active
[00:50.00]Eleventh line after active
[00:55.00]Twelfth line after active
''');

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: LyricsScreen(song: song, initialLyrics: lyrics),
        ),
      ),
    );
    await tester.pump();
    // First frame builds the off-screen target after the coarse jump; the
    // following frames run and settle the real RenderBox-centering tween.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final viewport = tester.getRect(
      find.byKey(const ValueKey('lyrics-scroll-view')),
    );
    final activeLine = tester.getRect(
      find.byKey(const ValueKey('lyrics-line-6')),
    );
    expect(
      activeLine.center.dy,
      moreOrLessEquals(viewport.center.dy - 32, epsilon: 2),
    );

    // The Kotlin layout keeps the highlight anchored when immersive mode
    // removes the playback dock and expands the lyric viewport.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    final immersiveViewport = tester.getRect(
      find.byKey(const ValueKey('lyrics-scroll-view')),
    );
    final immersiveActiveLine = tester.getRect(
      find.byKey(const ValueKey('lyrics-line-6')),
    );
    expect(
      immersiveActiveLine.center.dy,
      moreOrLessEquals(immersiveViewport.center.dy - 32, epsilon: 2),
    );
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
    for (final key in const <ValueKey<String>>[
      ValueKey('lyrics-playback-shuffle'),
      ValueKey('lyrics-playback-repeat'),
      ValueKey('lyrics-playback-favorite'),
    ]) {
      expect(tester.getSize(find.byKey(key)).height, 58);
    }
    await tester.tap(find.text('Adjust synchronization'));
    await tester.pump();
    expect(find.text('−.5'), findsOneWidget);
    expect(find.text('+.5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
