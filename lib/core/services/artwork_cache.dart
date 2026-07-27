import 'dart:typed_data';

import 'package:on_audio_query/on_audio_query.dart';

/// Single-flight encoded artwork cache shared by every UI surface.
///
/// Querying MediaStore artwork crosses the platform channel and may decode the
/// same embedded image repeatedly. PixelPlayer uses album-art caching on the
/// Compose side, so the Flutter port keeps one bounded cache as well.
abstract final class ArtworkCache {
  static const _maximumEntries = 128;
  static final Map<int, Future<Uint8List?>> _entries =
      <int, Future<Uint8List?>>{};

  static Future<Uint8List?> bytesForId(int mediaStoreId) {
    final existing = _entries.remove(mediaStoreId);
    if (existing != null) {
      _entries[mediaStoreId] = existing;
      return existing;
    }

    if (_entries.length >= _maximumEntries) {
      _entries.remove(_entries.keys.first);
    }

    final request = _load(mediaStoreId);
    _entries[mediaStoreId] = request;
    return request;
  }

  static Future<Uint8List?> _load(int mediaStoreId) async {
    try {
      final bytes = await OnAudioQuery().queryArtwork(
        mediaStoreId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 1024,
        quality: 94,
      );
      return bytes == null || bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  static void evict(int mediaStoreId) => _entries.remove(mediaStoreId);

  static void clear() => _entries.clear();
}
