import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/song.dart';

/// M3U export/share counterpart of PixelPlayer's `M3uManager` and playlist
/// batch actions in `PlaylistViewModel`.
abstract final class PlaylistTransferService {
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
