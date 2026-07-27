import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/details/artist_detail_screen.dart';

import 'fixtures/mock_library.dart';

void main() {
  testWidgets('artist detail mirrors the Kotlin collapsible album hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..songs = MockLibrary.songs
      ..libraryLoading = false;
    addTearDown(controller.dispose);
    final artist = controller.artists.first;

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(home: ArtistDetailScreen(artistId: artist.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(artist.name), findsWidgets);
    expect(
      find.text(
        '${artist.songs.length} '
        '${artist.songs.length == 1 ? 'Song' : 'Songs'}',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('artist-detail-back')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('artist-shuffle-star'))),
      const Size.square(92),
    );
    expect(find.text(artist.songs.first.album), findsOneWidget);
    for (final song in artist.songs) {
      expect(find.text(song.title), findsOneWidget);
    }

    await tester.tap(find.text(artist.songs.first.album));
    await tester.pumpAndSettle();
    for (final song in artist.songs) {
      expect(find.text(song.title), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
}
