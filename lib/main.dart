import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'core/data/lyrics_parser.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep enough decoded artwork for smooth lists without allowing the image
  // cache to dominate the process. Artwork widgets request display-sized
  // decodes, so 64 MiB comfortably covers the visible library and player.
  PaintingBinding.instance.imageCache
    ..maximumSize = 256
    ..maximumSizeBytes = 64 << 20;
  final platformServicesReady = _initializePlatformServices();
  runApp(PixelPlayApp(platformServicesReady: platformServicesReady));
}

Future<void> _initializePlatformServices() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId:
          'com.chiraitori.pixelplay.channel.audio_playback',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'drawable/ic_notification',
    );
    await LyricsParser.ensureRomanizationInitialized();
  } catch (error) {
    // Startup must not stay on Android's splash screen if an optional platform
    // service cannot initialize. Playback will surface its own error if used.
    debugPrint('PixelPlayer: platform bootstrap failed: $error');
  }
}
