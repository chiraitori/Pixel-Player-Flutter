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
    if (!Platform.isAndroid && !Platform.isIOS) return null;
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

  /// Returns the canonical MIME type implied by a file name or a file URI.
  ///
  /// MediaStore and MediaMetadataRetriever sometimes report a generic
  /// `audio/mp4` for unrelated formats. A real filename extension is more
  /// specific, so callers should prefer this value when it is available.
  static String? mimeTypeForFilePath(String? value) {
    final extension = fileExtensionFromPath(value);
    return extension == null ? null : mimeTypeForExtension(extension);
  }

  static String? mimeTypeForExtension(String extension) =>
      switch (extension.trim().toLowerCase()) {
        'mp3' => 'audio/mpeg',
        'm4a' || 'm4b' || 'm4p' || 'mp4' => 'audio/mp4',
        'aac' => 'audio/aac',
        'ogg' || 'oga' => 'audio/ogg',
        'opus' => 'audio/opus',
        'flac' => 'audio/flac',
        'wav' || 'wave' => 'audio/wav',
        'alac' => 'audio/alac',
        'aiff' || 'aif' || 'aifc' => 'audio/aiff',
        'wma' => 'audio/x-ms-wma',
        'amr' => 'audio/amr',
        'mid' || 'midi' => 'audio/midi',
        'ac3' || 'eac3' => 'audio/ac3',
        'dts' || 'dtshd' => 'audio/vnd.dts',
        'ape' => 'audio/ape',
        'wv' => 'audio/wavpack',
        'webm' => 'audio/webm',
        'mka' => 'audio/x-matroska',
        _ => null,
      };

  /// Extracts an extension from a filesystem path, file URI, or display name.
  /// Content URIs normally have no filename and correctly return `null`.
  static String? fileExtensionFromPath(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = Uri.tryParse(value);
    final candidate = (parsed?.path ?? value).split(RegExp(r'[\\/]')).last;
    final dotIndex = candidate.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == candidate.length - 1) return null;
    final extension = candidate.substring(dotIndex + 1).trim().toLowerCase();
    return RegExp(r'^[a-z0-9]{1,10}$').hasMatch(extension) ? extension : null;
  }

  /// Resolves a display label from the detected codec. A filename is used only
  /// when Android reports a generic MP4/M4A MIME type; it must not override a
  /// concrete result such as `audio/flac` for a wrongly named `.m4a` file.
  static String formatFor({
    String? filePath,
    String? contentUri,
    String? mimeType,
  }) {
    final normalizedMimeType = _normalizeMimeType(mimeType);
    final detectedFormat = _formatFromMime(normalizedMimeType);
    if (detectedFormat != null && !_isGenericMp4Mime(normalizedMimeType)) {
      return detectedFormat;
    }
    final extension =
        fileExtensionFromPath(filePath) ?? fileExtensionFromPath(contentUri);
    return extension == null
        ? (detectedFormat ?? '-')
        : _formatForExtension(extension);
  }

  /// Keeps a concrete codec detected by Android, but uses the extension to
  /// refine ambiguous `audio/mp4`/M4A values returned by MediaStore.
  static String? resolveMimeType({
    String? filePath,
    String? contentUri,
    String? reportedMimeType,
  }) {
    final normalizedReported = _normalizeMimeType(reportedMimeType);
    if (normalizedReported != null && !_isGenericMp4Mime(normalizedReported)) {
      return normalizedReported;
    }
    return mimeTypeForFilePath(filePath) ??
        mimeTypeForFilePath(contentUri) ??
        normalizedReported;
  }

  /// Converts a MIME type string to a short display format label, matching
  /// Kotlin's [AudioMetaUtils.mimeTypeToFormat] exactly.
  static String mimeTypeToFormat(String? mimeType) {
    return _formatFromMime(mimeType) ?? '-';
  }

  static String? _normalizeMimeType(String? mimeType) {
    final normalized = mimeType?.trim().toLowerCase().split(';').first;
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static bool _isGenericMp4Mime(String? mimeType) =>
      mimeType == 'audio/mp4' ||
      mimeType == 'audio/m4a' ||
      mimeType == 'audio/x-m4a' ||
      mimeType == 'audio/mp4a-latm';

  static String _formatForExtension(String extension) => switch (extension) {
    'mp3' => 'MP3',
    'm4a' || 'm4b' || 'm4p' => 'M4A',
    'mp4' => 'MP4',
    'aac' => 'AAC',
    'ogg' || 'oga' => 'OGG',
    'opus' => 'OPUS',
    'flac' => 'FLAC',
    'wav' || 'wave' => 'WAV',
    'alac' => 'ALAC',
    'aiff' || 'aif' || 'aifc' => 'AIFF',
    'wma' => 'WMA',
    'amr' => 'AMR',
    'mid' || 'midi' => 'MIDI',
    'ac3' || 'eac3' => 'AC3',
    'dts' || 'dtshd' => 'DTS',
    'ape' => 'APE',
    'wv' => 'WAVPACK',
    'webm' => 'WEBM',
    'mka' => 'MKA',
    _ => extension.toUpperCase(),
  };

  static String? _formatFromMime(String? mimeType) {
    final normalized = _normalizeMimeType(mimeType);
    if (normalized == null) return null;

    return switch (normalized) {
      'audio/mpeg' || 'audio/mp3' || 'audio/x-mp3' || 'audio/mpeg3' => 'MP3',

      'audio/flac' || 'audio/x-flac' => 'FLAC',

      'audio/wav' || 'audio/x-wav' || 'audio/wave' || 'audio/vnd.wave' => 'WAV',

      'audio/ogg' ||
      'application/ogg' ||
      'audio/vorbis' ||
      'audio/x-vorbis' => 'OGG',

      'audio/opus' || 'audio/x-opus' => 'OPUS',

      'audio/mp4' || 'audio/m4a' || 'audio/x-m4a' || 'audio/mp4a-latm' => 'M4A',

      'audio/aac' || 'audio/aacp' => 'AAC',

      'audio/amr' || 'audio/amr-wb' || 'audio/3gpp' => 'AMR',

      'audio/evrc' || 'audio/x-evrc' => 'EVRC',

      'audio/qcelp' || 'audio/x-qcelp' => 'QCELP',

      'audio/x-ima-adpcm' || 'audio/ima-adpcm' => 'IMA',

      'audio/alac' || 'audio/x-alac' => 'ALAC',

      'audio/aiff' || 'audio/x-aiff' || 'audio/aif' || 'audio/x-aifc' => 'AIFF',

      'audio/x-ms-wma' || 'audio/wma' => 'WMA',

      'audio/ac3' || 'audio/eac3' || 'audio/eac3-joc' => 'AC3',

      'audio/vnd.dts' || 'audio/vnd.dts.hd' => 'DTS',

      'audio/midi' ||
      'audio/x-midi' ||
      'audio/sp-midi' ||
      'audio/x-mid' => 'MIDI',

      _ => _fallbackFormat(normalized),
    };
  }

  static String? _fallbackFormat(String normalized) {
    if (normalized.contains('mp4a')) return 'M4A';
    if (normalized.contains('flac')) return 'FLAC';
    if (normalized.contains('opus')) return 'OPUS';
    if (normalized.contains('vorbis') || normalized.contains('ogg')) {
      return 'OGG';
    }
    if (normalized.contains('wav') || normalized.contains('wave')) {
      return 'WAV';
    }
    if (normalized.contains('aac')) return 'AAC';
    if (normalized.contains('mpeg') || normalized.contains('mp3')) {
      return 'MP3';
    }
    if (normalized.contains('amr')) return 'AMR';
    if (normalized.contains('alac')) return 'ALAC';
    if (normalized.contains('aiff') || normalized.contains('aif')) {
      return 'AIFF';
    }
    if (normalized.contains('wma')) return 'WMA';
    if (normalized.contains('dts')) return 'DTS';
    if (normalized.contains('eac3') || normalized.contains('ac3')) {
      return 'AC3';
    }
    if (normalized.contains('midi') || normalized.contains('x-mid')) {
      return 'MIDI';
    }
    if (normalized.startsWith('audio/')) {
      final sub = normalized.substring('audio/'.length).trim();
      return sub.isEmpty ? null : sub.toUpperCase();
    }
    return null;
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
