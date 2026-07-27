import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';
import 'package:pixelplayer_flutter/features/details/playlist_detail_screen.dart';

import 'fixtures/mock_library.dart';

void main() {
  testWidgets('playlist detail mirrors the Kotlin expressive action layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(setupComplete: true)
      ..songs = MockLibrary.songs
      ..playlists = MockLibrary.playlists
      ..libraryLoading = false;
    addTearDown(controller.dispose);
    final playlist = controller.playlists.first;

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(home: PlaylistDetailScreen(playlistId: playlist.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(playlist.name), findsWidgets);
    expect(find.byKey(const ValueKey('playlist-detail-back')), findsOneWidget);
    expect(find.text('Play it'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Reorder'), findsOneWidget);
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('Remove ${playlist.songs.first.title}'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
