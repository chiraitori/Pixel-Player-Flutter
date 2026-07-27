import 'dart:io';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/models/song.dart';
import '../../core/services/audio_meta_service.dart';
import 'music_library_repository.dart';

class MediaStoreMusicLibrary implements MusicLibraryRepository {
  MediaStoreMusicLibrary({OnAudioQuery? audioQuery})
    : _audioQuery = audioQuery ?? OnAudioQuery();

  final OnAudioQuery _audioQuery;

  @override
  Future<List<Song>> loadSongs({String? allowedDirectory}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const [];
    }

    final queried = await _audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    return queried
        .where((song) => song.isMusic != false && (song.duration ?? 0) > 0)
        .where(
          (song) =>
              allowedDirectory == null ||
              allowedDirectory.isEmpty ||
              song.data.startsWith(allowedDirectory),
        )
        .map(_mapSong)
        .toList(growable: false);
  }

  Song _mapSong(SongModel source) {
    final trackValue = source.track ?? 0;
    final track = trackValue > 1000 ? trackValue % 1000 : trackValue;
    final disc = trackValue > 1000 ? trackValue ~/ 1000 : 1;
    // `file_extension` comes from the MediaStore plugin and is occasionally
    // generic/wrong on vendor ROMs. The actual MediaStore path is authoritative.
    final extension =
        AudioMetaService.fileExtensionFromPath(source.data) ??
        source.fileExtension.trim().toLowerCase();
    final durationMs = source.duration ?? 0;
    final bitrate = durationMs > 0 && source.size > 0
        ? (source.size * 8000 / durationMs).round()
        : null;

    return Song(
      id: source.id.toString(),
      title: _clean(source.title, source.displayNameWOExt),
      artist: _clean(source.artist, 'Unknown artist'),
      album: _clean(source.album, 'Unknown album'),
      genre: _clean(source.genre, 'Unknown genre'),
      duration: Duration(milliseconds: source.duration ?? 0),
      colors: _colorsFor(source.albumId ?? source.id),
      year: 0,
      disc: disc,
      track: track,
      artistId: source.artistId,
      albumId: source.albumId,
      path: source.data,
      contentUri: source.uri,
      mediaStoreId: source.id,
      dateAdded: _dateFromSeconds(source.dateAdded),
      dateModified: _dateFromSeconds(source.dateModified),
      mimeType: AudioMetaService.mimeTypeForExtension(extension),
      fileSize: source.size,
      bitrate: bitrate,
    );
  }

  String _clean(String? value, String fallback) {
    final clean = value?.trim();
    if (clean == null ||
        clean.isEmpty ||
        clean == '<unknown>' ||
        clean == 'null') {
      return fallback;
    }
    return clean;
  }

  DateTime? _dateFromSeconds(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  List<Color> _colorsFor(int seed) {
    final hue = (seed.abs() * 47) % 360;
    return <Color>[
      HSVColor.fromAHSV(1, hue.toDouble(), .62, .72).toColor(),
      HSVColor.fromAHSV(1, (hue + 54) % 360, .48, .92).toColor(),
    ];
  }
}
