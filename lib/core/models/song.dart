import 'package:flutter/material.dart';

@immutable
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.duration,
    required this.colors,
    this.year = 2026,
    this.disc = 1,
    this.track = 1,
    this.artistId,
    this.albumId,
    this.path,
    this.contentUri,
    this.mediaStoreId,
    this.dateAdded,
    this.dateModified,
    this.mimeType,
    this.fileSize,
    this.bitrate,
    this.sampleRate,
    this.playbackHeaders = const <String, String>{},
    this.source = SongSource.local,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final Duration duration;
  final List<Color> colors;
  final int year;
  final int disc;
  final int track;
  final int? artistId;
  final int? albumId;
  final String? path;
  final String? contentUri;
  final int? mediaStoreId;
  final DateTime? dateAdded;
  final DateTime? dateModified;
  final String? mimeType;
  final int? fileSize;
  final int? bitrate;
  final int? sampleRate;
  final Map<String, String> playbackHeaders;
  final SongSource source;

  bool get isPlayable =>
      (contentUri != null && contentUri!.isNotEmpty) ||
      (path != null && path!.isNotEmpty);

  Uri? get playbackUri {
    final uri = contentUri;
    if (uri != null && uri.isNotEmpty) return Uri.parse(uri);
    final filePath = path;
    if (filePath != null && filePath.isNotEmpty) return Uri.file(filePath);
    return null;
  }

  String get durationLabel {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Song copyWith({
    String? genre,
    String? mimeType,
    int? bitrate,
    int? sampleRate,
    Map<String, String>? playbackHeaders,
  }) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      genre: genre ?? this.genre,
      duration: duration,
      colors: colors,
      year: year,
      disc: disc,
      track: track,
      artistId: artistId,
      albumId: albumId,
      path: path,
      contentUri: contentUri,
      mediaStoreId: mediaStoreId,
      dateAdded: dateAdded,
      dateModified: dateModified,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      playbackHeaders: playbackHeaders ?? this.playbackHeaders,
      source: source,
    );
  }
}

enum SongSource {
  local,
  googleDrive,
  telegram,
  netease,
  qqMusic,
  navidrome,
  jellyfin,
}

@immutable
class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.songs,
  });

  final String id;
  final String title;
  final String artist;
  final List<Song> songs;

  List<Color> get colors => songs.first.colors;
}

@immutable
class Artist {
  const Artist({required this.id, required this.name, required this.songs});

  final String id;
  final String name;
  final List<Song> songs;

  List<Color> get colors => songs.first.colors;
}

@immutable
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.songs,
    this.coverPath,
    this.coverColorValue,
    this.coverIconName,
    this.coverShape = 'smoothRect',
    this.coverShapeDetail1,
    this.coverShapeDetail2,
    this.coverShapeDetail3,
    this.coverShapeDetail4,
  });

  final String id;
  final String name;
  final List<Song> songs;
  final String? coverPath;
  final int? coverColorValue;
  final String? coverIconName;
  final String coverShape;
  final double? coverShapeDetail1;
  final double? coverShapeDetail2;
  final double? coverShapeDetail3;
  final double? coverShapeDetail4;

  Playlist copyWith({
    String? name,
    List<Song>? songs,
    String? coverPath,
    int? coverColorValue,
    String? coverIconName,
    String? coverShape,
    double? coverShapeDetail1,
    double? coverShapeDetail2,
    double? coverShapeDetail3,
    double? coverShapeDetail4,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      songs: songs ?? this.songs,
      coverPath: coverPath ?? this.coverPath,
      coverColorValue: coverColorValue ?? this.coverColorValue,
      coverIconName: coverIconName ?? this.coverIconName,
      coverShape: coverShape ?? this.coverShape,
      coverShapeDetail1: coverShapeDetail1 ?? this.coverShapeDetail1,
      coverShapeDetail2: coverShapeDetail2 ?? this.coverShapeDetail2,
      coverShapeDetail3: coverShapeDetail3 ?? this.coverShapeDetail3,
      coverShapeDetail4: coverShapeDetail4 ?? this.coverShapeDetail4,
    );
  }
}
