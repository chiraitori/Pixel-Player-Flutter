import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/song.dart';

/// The import result produced by PixelPlayer's M3U parser before the playlist
/// is persisted. Keeping IDs (rather than Song objects) preserves the order
/// written by the playlist file.
class ImportedM3uPlaylist {
  const ImportedM3uPlaylist({required this.name, required this.songIds});

  final String name;
  final List<String> songIds;
}

/// M3U export/share counterpart of PixelPlayer's `M3uManager` and playlist
/// batch actions in `PlaylistViewModel`.
abstract final class PlaylistTransferService {
  /// Ports `M3uManager.parseM3u` from the Kotlin app.
  ///
  /// Each non-comment line first matches a local path exactly, then falls back
  /// to the filename in the local path or media content URI. This intentionally
  /// keeps the M3U file's order and ignores unmatched entries.
  static ImportedM3uPlaylist parseM3u(
    String contents, {
    required String fileName,
    required Iterable<Song> library,
  }) {
    const fallbackName = 'Imported Playlist';
    final songs = library.toList(growable: false);
    final songsByPath = <String, Song>{
      for (final song in songs)
        if (song.path != null && song.path!.isNotEmpty) song.path!: song,
    };
    final songsByPathFileName = <String, List<Song>>{};
    final songsByContentUriFileName = <String, List<Song>>{};
    for (final song in songs) {
      final path = song.path;
      if (path != null && path.isNotEmpty) {
        (songsByPathFileName[_fileName(path)] ??= <Song>[]).add(song);
      }
      final contentUri = song.contentUri;
      if (contentUri != null && contentUri.isNotEmpty) {
        (songsByContentUriFileName[_fileName(contentUri)] ??= <Song>[]).add(
          song,
        );
      }
    }

    final songIds = <String>[];
    for (final rawLine in const LineSplitter().convert(contents)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final exact = songsByPath[line];
      final matched =
          exact ??
          songsByPathFileName[_fileName(line)]?.first ??
          songsByContentUriFileName[_fileName(line)]?.first;
      if (matched != null) songIds.add(matched.id);
    }

    final playlistName = fileName
        .replaceFirst(RegExp(r'\.m3u8$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\.m3u$', caseSensitive: false), '')
        .trim();
    return ImportedM3uPlaylist(
      name: playlistName.isEmpty ? fallbackName : playlistName,
      songIds: List.unmodifiable(songIds),
    );
  }

  static String _fileName(String value) {
    final slashIndex = value.lastIndexOf('/');
    return slashIndex == -1 ? value : value.substring(slashIndex + 1);
  }

  static Future<int?> exportPlaylists(List<Playlist> playlists) async {
    final directoryPath = await FilePicker.getDirectoryPath(
      dialogTitle: 'Export playlists',
    );
    if (directoryPath == null) return null;

    final directory = Directory(directoryPath);
    final usedNames = <String>{};
    for (final playlist in playlists) {
      var fileName = uniqueM3uName(playlist.name, usedNames);
      var suffix = 1;
      var file = File('${directory.path}${Platform.pathSeparator}$fileName');
      while (await file.exists()) {
        final base = safeFileName(playlist.name);
        fileName = '${base}_$suffix.m3u';
        suffix++;
        file = File('${directory.path}${Platform.pathSeparator}$fileName');
      }
      usedNames.add(fileName.toLowerCase());
      await file.writeAsString(m3uFor(playlist), flush: true);
    }
    return playlists.length;
  }

  static Future<void> sharePlaylists(
    List<Playlist> playlists, {
    Rect? sharePositionOrigin,
  }) async {
    if (playlists.isEmpty) return;
    late final XFile sharedFile;
    late final String fileName;
    if (playlists.length == 1) {
      fileName = '${safeFileName(playlists.first.name)}.m3u';
      sharedFile = XFile.fromData(
        utf8.encode(m3uFor(playlists.first)),
        mimeType: 'audio/mpegurl',
      );
    } else {
      final archive = Archive();
      final usedNames = <String>{};
      for (final playlist in playlists) {
        final entryName = uniqueM3uName(playlist.name, usedNames);
        archive.addFile(ArchiveFile.string(entryName, m3uFor(playlist)));
      }
      final firstName = safeFileName(playlists.first.name);
      fileName = 'Playlists_${firstName}_and_${playlists.length - 1}_more.zip';
      sharedFile = XFile.fromData(
        ZipEncoder().encodeBytes(archive),
        mimeType: 'application/zip',
      );
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [sharedFile],
        fileNameOverrides: [fileName],
        sharePositionOrigin: sharePositionOrigin,
        downloadFallbackEnabled: true,
      ),
    );
  }

  static String m3uFor(Playlist playlist) {
    final contents = StringBuffer('#EXTM3U\n');
    for (final song in playlist.songs) {
      contents.writeln(
        '#EXTINF:${song.duration.inSeconds},${song.artist} - ${song.title}',
      );
      contents.writeln(song.path ?? song.contentUri ?? '');
    }
    return contents.toString();
  }

  static String safeFileName(String value) {
    final clean = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    return clean.isEmpty ? 'Playlist' : clean;
  }

  static String uniqueM3uName(String playlistName, Set<String> usedNames) {
    final base = safeFileName(playlistName);
    var name = '$base.m3u';
    var suffix = 1;
    while (usedNames.contains(name.toLowerCase())) {
      name = '${base}_$suffix.m3u';
      suffix++;
    }
    usedNames.add(name.toLowerCase());
    return name;
  }
}
