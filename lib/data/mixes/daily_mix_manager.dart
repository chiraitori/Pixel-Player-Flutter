import 'dart:math';

import '../../core/models/song.dart';

class SongEngagement {
  const SongEngagement({
    this.playCount = 0,
    this.totalPlayDuration = Duration.zero,
    this.lastPlayed,
  });

  final int playCount;
  final Duration totalPlayDuration;
  final DateTime? lastPlayed;
}

/// Source-faithful port of Kotlin `DailyMixManager` ranking and diversity.
class DailyMixManager {
  const DailyMixManager();

  List<Song> generateDailyMix({
    required List<Song> allSongs,
    required Set<String> favoriteSongIds,
    required Map<String, SongEngagement> engagements,
    int limit = 30,
    DateTime? date,
  }) {
    if (allSongs.isEmpty) return const [];
    final today = date ?? DateTime.now();
    final random = Random(_dailySeed(today));
    final ranked = _rank(
      allSongs: allSongs,
      favorites: favoriteSongIds,
      engagements: engagements,
      random: random,
      now: today,
    );
    final diversity = _DiversityState();
    final selected = _pickWithDiversity(
      ranked,
      favoriteSongIds,
      limit,
      diversity,
    );
    return _fill(selected, allSongs, limit, random);
  }

  List<Song> generateYourMix({
    required List<Song> allSongs,
    required Set<String> favoriteSongIds,
    required Map<String, SongEngagement> engagements,
    int limit = 60,
    DateTime? date,
  }) {
    if (allSongs.isEmpty) return const [];
    final today = date ?? DateTime.now();
    final random = Random(_dailySeed(today) + 17);
    final ranked = _rank(
      allSongs: allSongs,
      favorites: favoriteSongIds,
      engagements: engagements,
      random: random,
      now: today,
    );
    final favoriteSize = min(limit, max(5, (limit * .3).floor()));
    final coreSize = min(limit, max(10, (limit * .45).floor()));
    final discoverySize = max(0, limit - favoriteSize - coreSize);
    final state = _DiversityState();
    final favorites = _pickWithDiversity(
      ranked.where((item) => favoriteSongIds.contains(item.song.id)).toList(),
      favoriteSongIds,
      favoriteSize,
      state,
    );
    final selectedIds = favorites.map((song) => song.id).toSet();
    final core = _pickWithDiversity(
      ranked.where((item) => !selectedIds.contains(item.song.id)).toList(),
      favoriteSongIds,
      coreSize,
      state,
    );
    selectedIds.addAll(core.map((song) => song.id));
    final discovery =
        ranked.where((item) => !selectedIds.contains(item.song.id)).toList()
          ..sort((a, b) {
            final score = b.discoveryScore.compareTo(a.discoveryScore);
            return score != 0 ? score : a.song.id.compareTo(b.song.id);
          });
    final discovered = _pickWithDiversity(
      discovery,
      favoriteSongIds,
      discoverySize,
      state,
    );
    return _fill(
      [...favorites, ...core, ...discovered],
      allSongs,
      limit,
      random,
    );
  }

  List<_RankedSong> _rank({
    required List<Song> allSongs,
    required Set<String> favorites,
    required Map<String, SongEngagement> engagements,
    required Random random,
    required DateTime now,
  }) {
    final byId = {for (final song in allSongs) song.id: song};
    final artistAffinity = <int?, double>{};
    final genreAffinity = <String, double>{};
    for (final entry in engagements.entries) {
      final song = byId[entry.key];
      if (song == null) continue;
      final stats = entry.value;
      final weight =
          stats.playCount + stats.totalPlayDuration.inMilliseconds / 60000;
      if (weight <= 0) continue;
      artistAffinity.update(
        song.artistId,
        (value) => value + weight,
        ifAbsent: () => weight,
      );
      final genre = _genreKey(song.genre);
      if (genre != null) {
        genreAffinity.update(
          genre,
          (value) => value + weight,
          ifAbsent: () => weight,
        );
      }
    }
    final favoriteArtists = <int?, int>{};
    for (final id in favorites) {
      final song = byId[id];
      if (song == null) continue;
      favoriteArtists.update(
        song.artistId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final maxPlays = max(
      1,
      engagements.values.fold(0, (value, item) => max(value, item.playCount)),
    );
    final maxDuration = max(
      1,
      engagements.values.fold(
        0,
        (value, item) => max(value, item.totalPlayDuration.inMilliseconds),
      ),
    );
    final maxArtist = max(1.0, _maxDouble(artistAffinity.values));
    final maxGenre = max(1.0, _maxDouble(genreAffinity.values));
    final maxFavoriteArtist = max(1, favoriteArtists.values.fold(0, max));

    final result = <_RankedSong>[];
    for (final song in allSongs) {
      final stats = engagements[song.id];
      final playScore = (stats?.playCount ?? 0) / maxPlays;
      final durationScore =
          (stats?.totalPlayDuration.inMilliseconds ?? 0) / maxDuration;
      final affinity = (playScore * .7 + durationScore * .3).clamp(0.0, 1.0);
      final genre = _genreKey(song.genre);
      final artistPreference = (artistAffinity[song.artistId] ?? 0) / maxArtist;
      final genrePreference = genre == null
          ? 0.0
          : (genreAffinity[genre] ?? 0) / maxGenre;
      final favoriteArtistPreference =
          (favoriteArtists[song.artistId] ?? 0) / maxFavoriteArtist;
      final preference = genre == null
          ? artistPreference * .6 + favoriteArtistPreference * .4
          : artistPreference * .45 +
                genrePreference * .35 +
                favoriteArtistPreference * .2;
      final recency = _recency(stats?.lastPlayed, now);
      final novelty = _novelty(song.dateAdded, now);
      final favorite = favorites.contains(song.id) ? 1.0 : 0.0;
      final baseline = stats == null ? .1 : 0.0;
      final score =
          preference * .45 +
          affinity * .25 +
          recency * .15 +
          favorite * .1 +
          novelty * .05 +
          baseline +
          random.nextDouble() * .005;
      result.add(
        _RankedSong(
          song: song,
          finalScore: score,
          discoveryScore:
              (1 - affinity).clamp(0.0, 1.0) * .6 +
              novelty * .25 +
              preference * .15,
        ),
      );
    }
    result.sort((a, b) {
      final score = b.finalScore.compareTo(a.finalScore);
      return score != 0 ? score : a.song.id.compareTo(b.song.id);
    });
    return result;
  }

  List<Song> _pickWithDiversity(
    List<_RankedSong> ranked,
    Set<String> favorites,
    int limit,
    _DiversityState state,
  ) {
    if (limit <= 0) return const [];
    final selected = <Song>[];
    for (final candidate in ranked) {
      if (selected.length >= limit) break;
      final song = candidate.song;
      final favorite = favorites.contains(song.id);
      final artistCount = state.artistCounts[song.artistId] ?? 0;
      if (artistCount >= (favorite ? 3 : 2)) continue;
      final genre = _genreKey(song.genre);
      final genreCap = genre == null
          ? _unknownGenreCap(limit, favorite)
          : _knownGenreCap(limit, favorite);
      if (genre == null) {
        if (state.unknownGenreCount >= genreCap) continue;
      } else if ((state.genreCounts[genre] ?? 0) >= genreCap) {
        continue;
      }
      selected.add(song);
      state.artistCounts[song.artistId] = artistCount + 1;
      if (genre == null) {
        state.unknownGenreCount++;
      } else {
        state.genreCounts.update(
          genre,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }
    for (final candidate in ranked) {
      if (selected.length >= limit) break;
      if (!selected.any((song) => song.id == candidate.song.id)) {
        selected.add(candidate.song);
      }
    }
    return selected;
  }

  List<Song> _fill(
    List<Song> selected,
    List<Song> allSongs,
    int limit,
    Random random,
  ) {
    final result = <Song>[];
    final ids = <String>{};
    for (final song in selected) {
      if (ids.add(song.id)) result.add(song);
    }
    final remaining = allSongs.where((song) => !ids.contains(song.id)).toList()
      ..shuffle(random);
    for (final song in remaining) {
      if (result.length >= limit) break;
      result.add(song);
    }
    return result.take(min(limit, result.length)).toList(growable: false);
  }

  int _dailySeed(DateTime date) {
    final day = date.difference(DateTime(date.year)).inDays + 1;
    return date.year * 1000 + day;
  }

  String? _genreKey(String genre) {
    final value = genre.trim().toLowerCase();
    return value.isEmpty || value.contains('unknown') ? null : value;
  }

  int _knownGenreCap(int limit, bool favorite) =>
      (limit <= 12 ? 2 : (limit <= 30 ? 3 : 4)) + (favorite ? 1 : 0);

  int _unknownGenreCap(int limit, bool favorite) =>
      (limit <= 12 ? 1 : (limit <= 30 ? 2 : 3)) + (favorite ? 1 : 0);

  double _recency(DateTime? lastPlayed, DateTime now) {
    if (lastPlayed == null) return .6;
    final days = max(0, now.difference(lastPlayed).inMinutes / 1440);
    if (days < 1) return .2;
    if (days < 3) return .5;
    if (days < 7) return .7;
    if (days < 14) return .85;
    return 1;
  }

  double _novelty(DateTime? dateAdded, DateTime now) {
    if (dateAdded == null) return 0;
    final days = max(0, now.difference(dateAdded).inMinutes / 1440);
    return (1 - days / 60).clamp(0.0, 1.0);
  }

  double _maxDouble(Iterable<double> values) =>
      values.fold(0.0, (value, item) => max(value, item));
}

class _RankedSong {
  const _RankedSong({
    required this.song,
    required this.finalScore,
    required this.discoveryScore,
  });

  final Song song;
  final double finalScore;
  final double discoveryScore;
}

class _DiversityState {
  final Map<int?, int> artistCounts = {};
  final Map<String, int> genreCounts = {};
  int unknownGenreCount = 0;
}
