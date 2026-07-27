import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/models/song.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/core/theme/pixelplay_theme.dart';
import 'package:pixelplayer_flutter/features/details/genre_detail_screen.dart';

void main() {
  testWidgets('genre detail reproduces the Kotlin artist and album hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final songs = <Song>[
      const Song(
        id: 'easier',
        title: 'EASIER',
        artist: 'The Vanished People',
        album: 'EASIER - Single',
        genre: 'Funk',
        duration: Duration(minutes: 3, seconds: 12),
        colors: [Color(0xFF4257D6), Color(0xFFC548C8)],
        track: 1,
      ),
      const Song(
        id: 'second',
        title: 'Second Song',
        artist: 'The Vanished People',
        album: 'EASIER - Single',
        genre: 'Funk',
        duration: Duration(minutes: 2, seconds: 50),
        colors: [Color(0xFF4257D6), Color(0xFFC548C8)],
        track: 2,
      ),
    ];
    final controller = AppController(setupComplete: true)
      ..songs = songs
      ..libraryLoading = false;
    addTearDown(controller.dispose);
    controller.playSong(songs.first, fromQueue: songs);
    controller.togglePlayPause();

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: PixelPlayTheme.light(),
          darkTheme: PixelPlayTheme.dark(),
          themeMode: ThemeMode.dark,
          home: const GenreDetailScreen(genreId: 'Funk'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Funk'), findsOneWidget);
    expect(find.text('The Vanished People'), findsWidgets);
    expect(find.text('EASIER - Single'), findsOneWidget);
    expect(find.text('2 Songs'), findsOneWidget);
    expect(find.text('EASIER'), findsWidgets);
    expect(find.byKey(const ValueKey('genre-mini-player')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Sort by artist'), findsOneWidget);
    expect(find.text('Sort by album'), findsOneWidget);
    expect(find.text('Sort by title'), findsOneWidget);
  });
}
