import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/models/song.dart';
import 'package:pixelplayer_flutter/features/library/quick_fill_screen.dart';

import 'fixtures/mock_library.dart';

void main() {
  testWidgets(
    'Quick Fill mirrors the Kotlin two-step flow on a compact phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      List<Song>? appliedSongs;
      String? appliedGenre;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorSchemeSeed: const Color(0xFF6750A4)),
          home: QuickFillDialog(
            songs: MockLibrary.songs.take(3).toList(),
            onApply: (songs, genre) async {
              appliedSongs = songs;
              appliedGenre = genre;
              return null;
            },
          ),
        ),
      );

      expect(find.text('Select songs'), findsOneWidget);
      expect(find.text('Select all'), findsOneWidget);

      await tester.tap(find.text('Afterglow'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Choose genre'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Rock'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.drag(find.byType(GridView), const Offset(0, -160));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rock'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Quick fill'));
      await tester.pumpAndSettle();

      expect(appliedSongs?.map((song) => song.id), ['afterglow']);
      expect(appliedGenre, 'Rock');
      expect(tester.takeException(), isNull);
    },
  );
}
