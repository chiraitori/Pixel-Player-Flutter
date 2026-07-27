import 'package:flutter/material.dart';

import 'package:pixelplayer_flutter/core/models/song.dart';

abstract final class MockLibrary {
  static const songs = <Song>[
    Song(
      id: 'afterglow',
      title: 'Afterglow',
      artist: 'Luna Vale',
      album: 'Neon Weather',
      genre: 'Dream Pop',
      duration: Duration(minutes: 3, seconds: 42),
      colors: [Color(0xFF7D49DD), Color(0xFFF376A3)],
      track: 1,
    ),
    Song(
      id: 'violet_horizon',
      title: 'Violet Horizon',
      artist: 'Aria Bloom',
      album: 'Soft Signals',
      genre: 'Alternative',
      duration: Duration(minutes: 4, seconds: 8),
      colors: [Color(0xFF3B56B4), Color(0xFF9F73E7)],
      track: 2,
    ),
    Song(
      id: 'night_drive',
      title: 'Night Drive',
      artist: 'Nova Arcade',
      album: 'City Lights',
      genre: 'Synthwave',
      duration: Duration(minutes: 3, seconds: 18),
      colors: [Color(0xFF141B59), Color(0xFFE84C8A)],
      track: 1,
    ),
    Song(
      id: 'paper_moons',
      title: 'Paper Moons',
      artist: 'Luna Vale',
      album: 'Neon Weather',
      genre: 'Dream Pop',
      duration: Duration(minutes: 4, seconds: 26),
      colors: [Color(0xFFFEA55F), Color(0xFFDC5B8C)],
      track: 3,
    ),
    Song(
      id: 'slow_bloom',
      title: 'Slow Bloom',
      artist: 'Mira June',
      album: 'Garden Static',
      genre: 'Indie',
      duration: Duration(minutes: 2, seconds: 59),
      colors: [Color(0xFF3C8F75), Color(0xFFF0C665)],
      track: 1,
    ),
    Song(
      id: 'satellite_heart',
      title: 'Satellite Heart',
      artist: 'Aria Bloom',
      album: 'Soft Signals',
      genre: 'Alternative',
      duration: Duration(minutes: 3, seconds: 51),
      colors: [Color(0xFF4D67A7), Color(0xFFE7A4C9)],
      track: 4,
    ),
    Song(
      id: 'glass_ocean',
      title: 'Glass Ocean',
      artist: 'Nova Arcade',
      album: 'City Lights',
      genre: 'Synthwave',
      duration: Duration(minutes: 4, seconds: 12),
      colors: [Color(0xFF006C7D), Color(0xFF75D9C7)],
      track: 5,
    ),
    Song(
      id: 'golden_hour',
      title: 'Golden Hour',
      artist: 'Mira June',
      album: 'Garden Static',
      genre: 'Indie',
      duration: Duration(minutes: 3, seconds: 35),
      colors: [Color(0xFFBF6C36), Color(0xFFF2CE76)],
      track: 6,
    ),
    Song(
      id: 'quiet_frequency',
      title: 'Quiet Frequency',
      artist: 'Echo Theory',
      album: 'Signal Loss',
      genre: 'Electronic',
      duration: Duration(minutes: 5, seconds: 2),
      colors: [Color(0xFF294B80), Color(0xFF6BD2DB)],
      track: 1,
    ),
    Song(
      id: 'rose_colored_noise',
      title: 'Rose-Colored Noise',
      artist: 'Echo Theory',
      album: 'Signal Loss',
      genre: 'Electronic',
      duration: Duration(minutes: 3, seconds: 47),
      colors: [Color(0xFF8A315E), Color(0xFFF78DA7)],
      track: 2,
    ),
  ];

  static final albums = _groupAlbums();
  static final artists = _groupArtists();
  static final playlists = <Playlist>[
    Playlist(id: 'favorites', name: 'Favorites', songs: songs.take(7).toList()),
    Playlist(
      id: 'night',
      name: 'Night Drive',
      songs: songs.skip(2).take(5).toList(),
    ),
    Playlist(
      id: 'discoveries',
      name: 'Fresh discoveries',
      songs: songs.reversed.take(6).toList(),
    ),
  ];

  static List<Album> _groupAlbums() {
    final groups = <String, List<Song>>{};
    for (final song in songs) {
      groups.putIfAbsent(song.album, () => []).add(song);
    }
    return [
      for (final entry in groups.entries)
        Album(
          id: entry.key.toLowerCase().replaceAll(' ', '_'),
          title: entry.key,
          artist: entry.value.first.artist,
          songs: entry.value,
        ),
    ];
  }

  static List<Artist> _groupArtists() {
    final groups = <String, List<Song>>{};
    for (final song in songs) {
      groups.putIfAbsent(song.artist, () => []).add(song);
    }
    return [
      for (final entry in groups.entries)
        Artist(
          id: entry.key.toLowerCase().replaceAll(' ', '_'),
          name: entry.key,
          songs: entry.value,
        ),
    ];
  }
}
