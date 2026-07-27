import 'dart:io';

import 'package:flutter/services.dart';

/// Reads accurate bitrate, sample rate, and MIME type from the native Android
/// [MediaMetadataRetriever] — the exact same approach used in the Kotlin app's
/// [AudioMetaUtils] / [MediaControllerSyncStateHolder].
///
/// Falls back gracefully on non-Android platforms or when the channel is
/// unavailable (unit tests, web, etc.).
class AudioMetaService {
  const AudioMetaService._();

  static const _channel = MethodChannel('com.chiraitori.pixelplay/audio_meta');

  /// Fetches audio metadata for the given content URI or file path.
  /// Returns `null` if the platform does not support this or reading fails.
  static Future<AudioMeta?> fetch(String uriOrPath) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getAudioMeta',
        {'uri': uriOrPath},
      );
      if (result == null) return null;
      return AudioMeta(
        mimeType: result['mimeType'] as String?,
        bitrate: result['bitrate'] as int?,
        sampleRate: result['sampleRate'] as int?,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Converts a MIME type string to a short display format label, matching
  /// Kotlin's [AudioMetaUtils.mimeTypeToFormat] exactly.
  static String mimeTypeToFormat(String? mimeType) {
    final normalized = mimeType?.trim().toLowerCase().split(';').first;
    if (normalized == null || normalized.isEmpty) return '-';

    return switch (normalized) {
      'audio/mpeg' ||
          'audio/mp3' ||
          'audio/x-mp3' ||
          'audio/mpeg3' => 'MP3',

      'audio/flac' || 'audio/x-flac' => 'FLAC',

      'audio/wav' ||
          'audio/x-wav' ||
          'audio/wave' ||
          'audio/vnd.wave' => 'WAV',

      'audio/ogg' ||
          'application/ogg' ||
          'audio/vorbis' ||
          'audio/x-vorbis' => 'OGG',

      'audio/opus' || 'audio/x-opus' => 'OPUS',

      'audio/mp4' ||
          'audio/m4a' ||
          'audio/x-m4a' ||
          'audio/mp4a-latm' => 'M4A',

      'audio/aac' || 'audio/aacp' => 'AAC',

      'audio/amr' ||
          'audio/amr-wb' ||
          'audio/3gpp' => 'AMR',

      'audio/evrc' || 'audio/x-evrc' => 'EVRC',

      'audio/qcelp' || 'audio/x-qcelp' => 'QCELP',

      'audio/x-ima-adpcm' || 'audio/ima-adpcm' => 'IMA',

      'audio/alac' || 'audio/x-alac' => 'ALAC',

      'audio/aiff' ||
          'audio/x-aiff' ||
          'audio/aif' ||
          'audio/x-aifc' => 'AIFF',

      'audio/x-ms-wma' || 'audio/wma' => 'WMA',

      'audio/ac3' ||
          'audio/eac3' ||
          'audio/eac3-joc' => 'AC3',

      'audio/vnd.dts' || 'audio/vnd.dts.hd' => 'DTS',

      'audio/midi' ||
          'audio/x-midi' ||
          'audio/sp-midi' ||
          'audio/x-mid' => 'MIDI',

      _ => _fallbackFormat(normalized),
    };
  }

  static String _fallbackFormat(String normalized) {
    if (normalized.contains('mp4a')) return 'M4A';
    if (normalized.contains('flac')) return 'FLAC';
    if (normalized.contains('opus')) return 'OPUS';
    if (normalized.contains('vorbis') || normalized.contains('ogg')) return 'OGG';
    if (normalized.contains('wav') || normalized.contains('wave')) return 'WAV';
    if (normalized.contains('aac')) return 'AAC';
    if (normalized.contains('mpeg') || normalized.contains('mp3')) return 'MP3';
    if (normalized.contains('amr')) return 'AMR';
    if (normalized.contains('alac')) return 'ALAC';
    if (normalized.contains('aiff') || normalized.contains('aif')) return 'AIFF';
    if (normalized.contains('wma')) return 'WMA';
    if (normalized.contains('dts')) return 'DTS';
    if (normalized.contains('eac3') || normalized.contains('ac3')) return 'AC3';
    if (normalized.contains('midi') || normalized.contains('x-mid')) return 'MIDI';
    if (normalized.startsWith('audio/')) {
      final sub = normalized.substring('audio/'.length).trim();
      return sub.isEmpty ? '-' : sub.toUpperCase();
    }
    return '-';
  }
}

class AudioMeta {
  const AudioMeta({this.mimeType, this.bitrate, this.sampleRate});

  /// Full MIME type string, e.g. "audio/mp4", "audio/flac".
  final String? mimeType;

  /// Bitrate in bits-per-second (NOT kbps). Divide by 1000 to get kbps.
  final int? bitrate;

  /// Sample rate in Hz.
  final int? sampleRate;
}
