import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'core/data/lyrics_parser.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
