import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../core/models/song.dart';

/// Persistent, cache-first counterpart to PixelPlay's Room `songs` table.
///
/// The cache only contains local MediaStore songs. Cloud providers keep their
/// own persisted state and are merged by [AppController] after this cache is
/// read. That lets a cold app render its previous library before MediaStore is
/// queried again.
class MusicLibraryCache {
  MusicLibraryCache({Future<Database> Function()? openDatabase})
    : _openDatabase = openDatabase ?? _open;

  static const _databaseName = 'pixelplay_library.db';
  static const _table = 'local_songs';

  final Future<Database> Function() _openDatabase;
  Future<Database>? _database;

  Future<List<Song>> loadSongs() async {
    final database = await _getDatabase();
    final rows = await database.query(
      _table,
      orderBy: 'date_added_ms DESC, id ASC',
    );
    return rows.map(_songFromRow).toList(growable: false);
  }

  /// Applies a MediaStore scan atomically, just like Room's incremental upsert.
  ///
  /// Unchanged rows are left alone; deleted MediaStore ids are removed and new
  /// or modified rows are replaced in the same transaction. Keeping this work
  /// in SQLite means the UI never has to wait for a fresh scan on the next app
  /// launch.
  Future<MusicLibraryCacheSyncResult> sync(List<Song> songs) async {
    final database = await _getDatabase();
    return database.transaction((transaction) async {
      final existingRows = await transaction.query(
        _table,
        columns: const ['id', 'sync_signature'],
      );
      final existingSignatures = <String, String>{
        for (final row in existingRows)
          row['id'] as String: row['sync_signature'] as String,
      };
      final incomingIds = songs.map((song) => song.id).toSet();
      final deletedIds = existingSignatures.keys
          .where((id) => !incomingIds.contains(id))
          .toList(growable: false);
      final batch = transaction.batch();

      for (final id in deletedIds) {
        batch.delete(_table, where: 'id = ?', whereArgs: [id]);
      }

      var inserted = 0;
      var updated = 0;
      for (final song in songs) {
        final row = _rowForSong(song);
        final previousSignature = existingSignatures[song.id];
        if (previousSignature == row['sync_signature']) continue;
        if (previousSignature == null) {
          inserted++;
        } else {
          updated++;
        }
        batch.insert(_table, row, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit(noResult: true);
      return MusicLibraryCacheSyncResult(
        inserted: inserted,
        updated: updated,
        deleted: deletedIds.length,
      );
    });
  }

  Future<Database> _getDatabase() => _database ??= _openDatabase();

  static Future<Database> _open() async {
    final databasesPath = await getDatabasesPath();
    return openDatabase(
      path.join(databasesPath, _databaseName),
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            album TEXT NOT NULL,
            genre TEXT NOT NULL,
            duration_ms INTEGER NOT NULL,
            color_one INTEGER NOT NULL,
            color_two INTEGER NOT NULL,
            year INTEGER NOT NULL,
            disc INTEGER NOT NULL,
            track INTEGER NOT NULL,
            artist_id INTEGER,
            album_id INTEGER,
            file_path TEXT,
            content_uri TEXT,
            media_store_id INTEGER,
            date_added_ms INTEGER,
            date_modified_ms INTEGER,
            mime_type TEXT,
            file_size INTEGER,
            bitrate INTEGER,
            sample_rate INTEGER,
            sync_signature TEXT NOT NULL
          )
        ''');
        await database.execute(
          'CREATE INDEX local_songs_date_added_idx '
          'ON $_table(date_added_ms DESC)',
        );
      },
    );
  }

  static Map<String, Object?> _rowForSong(Song song) {
    final colors = song.colors.isEmpty
        ? const [Color(0xFF555555), Color(0xFF888888)]
        : song.colors;
    final row = <String, Object?>{
      'id': song.id,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'genre': song.genre,
      'duration_ms': song.duration.inMilliseconds,
      'color_one': colors.first.toARGB32(),
      'color_two': (colors.length > 1 ? colors[1] : colors.first).toARGB32(),
      'year': song.year,
      'disc': song.disc,
      'track': song.track,
      'artist_id': song.artistId,
      'album_id': song.albumId,
      'file_path': song.path,
      'content_uri': song.contentUri,
      'media_store_id': song.mediaStoreId,
      'date_added_ms': song.dateAdded?.millisecondsSinceEpoch,
      'date_modified_ms': song.dateModified?.millisecondsSinceEpoch,
      'mime_type': song.mimeType,
      'file_size': song.fileSize,
      'bitrate': song.bitrate,
      'sample_rate': song.sampleRate,
    };
    row['sync_signature'] = jsonEncode(row);
    return row;
  }

  static Song _songFromRow(Map<String, Object?> row) => Song(
    id: row['id']! as String,
    title: row['title']! as String,
    artist: row['artist']! as String,
    album: row['album']! as String,
    genre: row['genre']! as String,
    duration: Duration(milliseconds: row['duration_ms']! as int),
    colors: [Color(row['color_one']! as int), Color(row['color_two']! as int)],
    year: row['year']! as int,
    disc: row['disc']! as int,
    track: row['track']! as int,
    artistId: row['artist_id'] as int?,
    albumId: row['album_id'] as int?,
    path: row['file_path'] as String?,
    contentUri: row['content_uri'] as String?,
    mediaStoreId: row['media_store_id'] as int?,
    dateAdded: _dateFromMilliseconds(row['date_added_ms'] as int?),
    dateModified: _dateFromMilliseconds(row['date_modified_ms'] as int?),
    mimeType: row['mime_type'] as String?,
    fileSize: row['file_size'] as int?,
    bitrate: row['bitrate'] as int?,
    sampleRate: row['sample_rate'] as int?,
  );

  static DateTime? _dateFromMilliseconds(int? value) =>
      value == null || value <= 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(value);
}

@immutable
class MusicLibraryCacheSyncResult {
  const MusicLibraryCacheSyncResult({
    required this.inserted,
    required this.updated,
    required this.deleted,
  });

  final int inserted;
  final int updated;
  final int deleted;

  bool get changed => inserted > 0 || updated > 0 || deleted > 0;
}
