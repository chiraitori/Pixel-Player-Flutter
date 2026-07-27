import 'package:flutter/material.dart';

IconData genreIconFor(String rawGenre) {
  final genre = rawGenre.toLowerCase().trim();
  if (_contains(genre, ['metal', 'core', 'rock', 'punk', 'grunge', 'emo'])) {
    return Icons.electric_bolt_rounded;
  }
  if (_contains(genre, ['rap', 'hip hop', 'trap', 'drill', 'grime'])) {
    return Icons.mic_external_on_rounded;
  }
  if (_contains(genre, ['pop', 'hit', 'chart'])) {
    return Icons.mic_rounded;
  }
  if (_contains(genre, ['r&b', 'rnb', 'soul', 'funk', 'disco'])) {
    return Icons.piano_rounded;
  }
  if (_contains(genre, [
    'edm',
    'electronic',
    'techno',
    'house',
    'trance',
    'dubstep',
    'dnb',
    'synthwave',
  ])) {
    return Icons.graphic_eq_rounded;
  }
  if (genre.contains('jazz')) return Icons.music_note_rounded;
  if (_contains(genre, ['classical', 'orchestra', 'opera', 'baroque'])) {
    return Icons.piano_rounded;
  }
  if (_contains(genre, ['country', 'folk', 'acoustic', 'bluegrass'])) {
    return Icons.music_note_rounded;
  }
  if (_contains(genre, ['reggae', 'ska', 'latin', 'salsa', 'bachata'])) {
    return Icons.album_rounded;
  }
  if (_contains(genre, ['soundtrack', 'ost', 'score'])) {
    return Icons.movie_filter_rounded;
  }
  if (_contains(genre, ['game', 'vgm', 'video game'])) {
    return Icons.sports_esports_rounded;
  }
  if (_contains(genre, ['ambient', 'sleep', 'relax', 'meditation', 'chill'])) {
    return Icons.bedtime_rounded;
  }
  if (_contains(genre, ['workout', 'gym', 'fitness'])) {
    return Icons.fitness_center_rounded;
  }
  if (_contains(genre, ['party', 'club'])) return Icons.celebration_rounded;
  if (_contains(genre, ['focus', 'study'])) return Icons.edit_rounded;
  return Icons.library_music_rounded;
}

bool _contains(String value, List<String> terms) => terms.any(value.contains);
