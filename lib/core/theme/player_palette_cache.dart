import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';
import 'artwork_color_extractor.dart';

/// Shared, single-flight artwork palette cache for mini and expanded players.
class PlayerPaletteCache {
  PlayerPaletteCache._();

  static final Map<int, Future<Color>> _seeds = <int, Future<Color>>{};

  static Future<Color> seedFor(Song song) {
    final fallback = song.colors.isEmpty
        ? Colors.deepPurple
        : song.colors.first;
    final mediaStoreId = song.mediaStoreId;
    if (mediaStoreId == null) return Future<Color>.value(fallback);

    return _seeds.putIfAbsent(mediaStoreId, () async {
      try {
        final artwork = await OnAudioQuery().queryArtwork(
          mediaStoreId,
          ArtworkType.AUDIO,
          format: ArtworkFormat.JPEG,
          size: 256,
          quality: 90,
        );
        if (artwork == null || artwork.isEmpty) return fallback;
        return await extractPixelPlayerArtworkSeed(artwork) ?? fallback;
      } catch (_) {
        return fallback;
      }
    });
  }
}
