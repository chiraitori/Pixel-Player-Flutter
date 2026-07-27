import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/details/album_detail_screen.dart';

import 'fixtures/mock_library.dart';

void main() {
  testWidgets('album detail mirrors the Kotlin expressive hierarchy', (
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
    final album = controller.albums.first;

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(home: AlbumDetailScreen(albumId: album.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(album.title), findsOneWidget);
    expect(
      find.text(
        '${album.artist} • ${album.songs.length} '
        '${album.songs.length == 1 ? 'Song' : 'Songs'}',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('album-detail-back')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('album-shuffle-star'))),
      const Size.square(92),
    );
    for (final song in album.songs) {
      expect(find.text(song.title), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
