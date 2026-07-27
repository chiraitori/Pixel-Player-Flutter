import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'core/data/lyrics_parser.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId:
        'com.chiraitori.pixelplay.channel.audio_playback',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  await LyricsParser.ensureRomanizationInitialized();
  runApp(const PixelPlayApp());
}
