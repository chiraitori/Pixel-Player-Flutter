class LyricsDocument {
  const LyricsDocument({
    required this.raw,
    this.plain = const <String>[],
    this.synced = const <SyncedLyricLine>[],
    this.fromRemote = false,
  });

  final String raw;
  final List<String> plain;
  final List<SyncedLyricLine> synced;
  final bool fromRemote;

  bool get hasLyrics => plain.isNotEmpty || synced.isNotEmpty;
  bool get hasSynced => synced.isNotEmpty;
}

class SyncedLyricLine {
  const SyncedLyricLine({
    required this.time,
    required this.text,
    this.words = const <SyncedLyricWord>[],
    this.translation,
    this.romanization,
  });

  final Duration time;
  final String text;
  final List<SyncedLyricWord> words;
  final String? translation;
  final String? romanization;
}

class SyncedLyricWord {
  const SyncedLyricWord({
    required this.time,
    required this.text,
    this.startsNewWord = true,
  });

  final Duration time;
  final String text;
  final bool startsNewWord;
}

class LyricsSearchResult {
  const LyricsSearchResult({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.duration,
    required this.document,
  });

  final int id;
  final String trackName;
  final String artistName;
  final String albumName;
  final Duration duration;
  final LyricsDocument document;
}

enum LyricsSourcePreference {
  onlineFirst,
  embeddedFirst,
  localFirst;

  static LyricsSourcePreference fromSetting(String value) {
    return switch (value.toLowerCase()) {
      'online first' => LyricsSourcePreference.onlineFirst,
      'local files first' => LyricsSourcePreference.localFirst,
      _ => LyricsSourcePreference.embeddedFirst,
    };
  }
}
