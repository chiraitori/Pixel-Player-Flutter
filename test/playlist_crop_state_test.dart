import 'package:flutter_test/flutter_test.dart';
import 'package:pixelplayer_flutter/core/state/app_controller.dart';

import 'fixtures/mock_library.dart';

void main() {
  test('playlist image crop transform survives playlist creation', () {
    final controller = AppController(setupComplete: true)
      ..songs = MockLibrary.songs;
    addTearDown(controller.dispose);

    controller.createPlaylist(
      'Cropped cover',
      [MockLibrary.songs.first.id],
      coverPath: 'C:/covers/cropped.jpg',
      coverImageScale: 1.75,
      coverImagePanX: -.2,
      coverImagePanY: .15,
    );

    final playlist = controller.playlists.single;
    expect(playlist.coverPath, 'C:/covers/cropped.jpg');
    expect(playlist.coverImageScale, 1.75);
    expect(playlist.coverImagePanX, -.2);
    expect(playlist.coverImagePanY, .15);
  });
}
