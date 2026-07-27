import 'package:flutter_taglib/flutter_taglib.dart';

import '../models/song.dart';

class MetadataWriteResult {
  const MetadataWriteResult({
    required this.updatedSongIds,
    required this.failures,
  });

  final Set<String> updatedSongIds;
  final Map<String, String> failures;

  bool get isComplete => failures.isEmpty;
}

/// Writes edits to the source audio files, matching PixelPlay's batch editor.
class SongMetadataWriter {
  const SongMetadataWriter();

  Future<MetadataWriteResult> writeGenre(
    Iterable<Song> songs,
    String genre,
  ) async {
    final updated = <String>{};
    final failures = <String, String>{};
    final normalizedGenre = genre.trim();
    if (normalizedGenre.isEmpty) {
      return MetadataWriteResult(
        updatedSongIds: updated,
        failures: {for (final song in songs) song.id: 'Genre cannot be empty.'},
      );
    }

    for (final song in songs) {
      final location = _writableLocation(song);
      if (location == null) {
        failures[song.id] = 'This source cannot be edited.';
        continue;
      }

      TagLibFile? file;
      try {
        file = await TagLibFile.openAsync(location, writeAccess: true);
        if (file == null) {
          failures[song.id] =
              TagLibFile.lastError ?? 'Could not open the audio file.';
          continue;
        }
        file.genre = normalizedGenre;
        if (file.save()) {
          updated.add(song.id);
        } else {
          failures[song.id] =
              TagLibFile.lastError ?? 'Could not save the genre tag.';
        }
      } catch (error) {
        failures[song.id] = error.toString();
      } finally {
        file?.close();
      }
    }

    return MetadataWriteResult(updatedSongIds: updated, failures: failures);
  }

  String? _writableLocation(Song song) {
    if (song.source != SongSource.local) return null;
    final contentUri = song.contentUri;
    if (contentUri != null && contentUri.startsWith('content://')) {
      return contentUri;
    }
    final path = song.path;
    if (path != null && path.isNotEmpty) return path;
    return contentUri?.isNotEmpty == true ? contentUri : null;
  }
}
