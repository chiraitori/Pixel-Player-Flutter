import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' hide PlaybackEvent;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import '../models/lyrics.dart';
import '../data/ai/gemini_ai_client.dart';
import '../data/lyrics_service.dart';
import '../services/audio_meta_service.dart';
import '../services/google_cast_service.dart';
import '../services/song_metadata_writer.dart';
import '../../data/library/media_store_music_library.dart';
import '../../data/library/music_library_repository.dart';
import '../../data/mixes/daily_mix_manager.dart';
import '../../data/providers/google_drive/google_drive_api_service.dart';
import '../../data/providers/google_drive/google_drive_auth_service.dart';
import '../../data/stats/playback_stats_repository.dart';
import '../../features/shell/player_internal_navigation_bar.dart';

class AppController extends ChangeNotifier {
  static const defaultArtistDelimiters = <String>[';'];
  static const defaultArtistWordDelimiters = <String>[
    'featuring',
    'feat.',
    'feat',
    'ft.',
    'ft',
    'vs.',
    'vs',
    'versus',
    'with',
    'prod.',
    'prod',
  ];
  factory AppController({bool setupComplete = false}) {
    return AppController._(setupComplete);
  }

  AppController._(this._setupComplete) {
    GoogleCastService.instance.addListener(_syncGoogleCastState);
  }

  bool _setupComplete;
  bool initialized = false;
  ThemeMode themeMode = ThemeMode.system;
  int selectedTab = 0;
  Song? currentSong;
  List<Song> queue = const [];
  bool isPlaying = false;
  bool shuffleEnabled = false;
  int repeatMode = 0;
  final Set<String> _favoriteSongIds = <String>{};
  final List<String> _playbackHistoryIds = <String>[];
  final List<String> searchHistory = <String>[];
  final Map<String, int> _playCounts = <String, int>{};
  final Map<String, int> _totalPlayedMs = <String, int>{};
  final Map<String, int> _lastPlayedAtMs = <String, int>{};
  final List<PlaybackEvent> _playbackEvents = <PlaybackEvent>[];
  final Map<String, dynamic> _settings = <String, dynamic>{};
  final DailyMixManager _dailyMixManager = const DailyMixManager();
  final GeminiAiClient _geminiAiClient = const GeminiAiClient();
  List<Song>? _dailyMixOverride;
  bool dailyMixGenerating = false;
  String? dailyMixAiStatus;
  String? dailyMixAiError;
  final PlaybackStatsRepository _statsRepository =
      const PlaybackStatsRepository();
  bool fullPlayerVisible = false;
  PixelNavBarStyle navBarStyle = PixelNavBarStyle.floating;
  bool navBarCompactMode = false;
  double navBarCornerRadius = 32;
  bool libraryCompactMode = false;
  List<Song> songs = const [];
  List<Playlist> playlists = const [];
  bool libraryLoading = true;
  Object? libraryError;
  final ValueNotifier<Duration> positionListenable = ValueNotifier(
    Duration.zero,
  );
  Duration get position => positionListenable.value;
  set position(Duration value) => positionListenable.value = value;
  Timer? _progressTimer;
  Timer? _dismissUndoTimer;
  Timer? _sleepTimer;
  Timer? _sleepTimerTicker;
  DateTime? sleepTimerEnd;
  bool sleepAtEndOfTrack = false;
  Song? _dismissedSong;
  List<Song> _dismissedQueue = const [];
  Duration _dismissedPosition = Duration.zero;
  bool showDismissUndoBar = false;
  static const dismissUndoDuration = Duration(milliseconds: 4000);
  SharedPreferencesAsync? _preferences;
  MusicLibraryRepository? _musicLibrary;
  AudioPlayer? _audioPlayer;
  AndroidEqualizer? _equalizer;
  AndroidLoudnessEnhancer? _loudnessEnhancer;
  List<Song> _audioQueue = const [];
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];

  static const _setupCompleteKey = 'setup_complete';
  static const _themeModeKey = 'app_theme_mode';
  static const _navBarStyleKey = 'nav_bar_style';
  static const _navBarCompactKey = 'nav_bar_compact_mode';
  static const _navBarRadiusKey = 'nav_bar_corner_radius';
  static const _libraryCompactKey = 'library_compact_mode';
  static const _favoritesKey = 'favorite_song_ids';
  static const _playbackHistoryKey = 'playback_history_ids';
  static const _playlistsKey = 'local_playlists';
  static const _playCountsKey = 'song_play_counts';
  static const _engagementsKey = 'song_engagements';
  static const _playbackEventsKey = 'playback_events';
  static const _settingsKey = 'ported_settings';
  static const _searchHistoryKey = 'search_history';
  static const _queueKey = 'playback_queue_ids';
  static const _currentSongKey = 'playback_current_song_id';
  static const _positionKey = 'playback_position_ms';
  int _lastPersistedPositionSecond = -1;

  bool get setupComplete => _setupComplete;
  List<Song> get favoriteSongs =>
      songs.where((song) => _favoriteSongIds.contains(song.id)).toList();
  List<Song> get recentlyPlayedSongs {
    final byId = {for (final song in songs) song.id: song};
    return _playbackHistoryIds
        .map((id) => byId[id])
        .whereType<Song>()
        .toList(growable: false);
  }

  int playCountFor(Song song) => _playCounts[song.id] ?? 0;
  DateTime? lastPlayedFor(Song song) => _lastPlayedDate(song.id);
  Map<String, SongEngagement> get _engagements => {
    for (final song in songs)
      song.id: SongEngagement(
        playCount: _playCounts[song.id] ?? 0,
        totalPlayDuration: Duration(milliseconds: _totalPlayedMs[song.id] ?? 0),
        lastPlayed: _lastPlayedDate(song.id),
      ),
  };
  DateTime? _lastPlayedDate(String songId) {
    final milliseconds = _lastPlayedAtMs[songId];
    return milliseconds == null || milliseconds <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  List<Song> get dailyMixSongs =>
      _dailyMixOverride ??
      _dailyMixManager.generateDailyMix(
        allSongs: songs,
        favoriteSongIds: _favoriteSongIds,
        engagements: _engagements,
      );
  List<Song> get yourMixSongs => _dailyMixManager.generateYourMix(
    allSongs: songs,
    favoriteSongIds: _favoriteSongIds,
    engagements: _engagements,
  );
  PlaybackStatsSnapshot statsFor(DateTime? start) {
    final events = [..._playbackEvents];
    if (events.isNotEmpty &&
        currentSong != null &&
        events.last.songId == currentSong!.id &&
        position > Duration.zero) {
      events[events.length - 1] = events.last.copyWith(
        listenedDuration: position,
      );
    }
    return _statsRepository.summarize(
      events: events,
      songs: songs,
      start: start,
    );
  }

  bool boolSetting(String key, bool fallback) =>
      _settings[key] is bool ? _settings[key] as bool : fallback;
  String stringSetting(String key, String fallback) =>
      _settings[key] is String ? _settings[key] as String : fallback;
  double doubleSetting(String key, double fallback) =>
      _settings[key] is num ? (_settings[key] as num).toDouble() : fallback;
  List<double> get equalizerBands {
    final stored = _settings['equalizer_bands'];
    if (stored is! List) return const [0, 0, 0, 0, 0];
    return stored.map((value) => (value as num).toDouble()).toList();
  }

  int get totalPlayCount =>
      _playCounts.values.fold(0, (total, count) => total + count);
  Duration get estimatedListeningTime {
    if (_totalPlayedMs.isNotEmpty) {
      return Duration(
        milliseconds: _totalPlayedMs.values.fold(
          0,
          (total, item) => total + item,
        ),
      );
    }
    final byId = {for (final song in songs) song.id: song};
    var milliseconds = 0;
    for (final entry in _playCounts.entries) {
      milliseconds +=
          (byId[entry.key]?.duration.inMilliseconds ?? 0) * entry.value;
    }
    return Duration(milliseconds: milliseconds);
  }

  String? get sleepTimerLabel {
    if (sleepAtEndOfTrack) return 'End of track';
    final end = sleepTimerEnd;
    if (end == null) return null;
    final remaining = end.difference(DateTime.now());
    if (remaining.isNegative) return null;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  List<Album> get albums {
    final grouped = <String, List<Song>>{};
    for (final song in songs) {
      grouped.putIfAbsent('${song.albumId}:${song.album}', () => []).add(song);
    }
    final minimumTracks = doubleSetting(
      'library_min_tracks_per_album',
      1,
    ).round();
    return [
      for (final entry in grouped.entries)
        if (entry.value.length >= minimumTracks)
          Album(
            id: entry.key,
            title: entry.value.first.album,
            artist: entry.value.first.artist,
            songs: entry.value,
          ),
    ];
  }

  List<Artist> get artists {
    final grouped = <String, List<Song>>{};
    final displayNames = <String, String>{};
    for (final song in songs) {
      final names = boolSetting('artist_extract_from_title', true)
          ? splitArtistNames(song.artist)
          : [song.artist];
      for (final name in names) {
        final key = name.toLowerCase();
        displayNames.putIfAbsent(key, () => name);
        grouped.putIfAbsent(key, () => []).add(song);
      }
    }
    return [
      for (final entry in grouped.entries)
        Artist(
          id: '${entry.value.first.artistId ?? 'artist'}:${entry.key}',
          name: displayNames[entry.key]!,
          songs: entry.value,
        ),
    ];
  }

  List<String> splitArtistNames(String value) {
    final delimiters = stringListSetting(
      'artist_character_delimiters',
      defaultArtistDelimiters,
    );
    final words = stringListSetting(
      'artist_word_delimiters',
      defaultArtistWordDelimiters,
    );
    var pieces = <String>[value];
    for (final delimiter in delimiters.where((item) => item.isNotEmpty)) {
      pieces = pieces.expand((item) => item.split(delimiter)).toList();
    }
    for (final word in words.where((item) => item.trim().isNotEmpty)) {
      final escaped = RegExp.escape(word.trim());
      final pattern = RegExp(
        '(?:^|\\s+)$escaped(?=\\s+|\$)',
        caseSensitive: false,
      );
      pieces = pieces.expand((item) => item.split(pattern)).toList();
    }
    final seen = <String>{};
    return [
      for (final piece in pieces.map((item) => item.trim()))
        if (piece.isNotEmpty && seen.add(piece.toLowerCase())) piece,
    ];
  }

  Future<void> initialize({
    bool ignoreStoredSetup = false,
    bool platformServicesEnabled = true,
  }) async {
    String? storedPlaylists;
    List<String> storedQueue = const [];
    String? storedCurrentSong;
    int storedPositionMs = 0;
    try {
      final preferences = _preferences ??= SharedPreferencesAsync();
      if (!ignoreStoredSetup) {
        _setupComplete =
            await preferences.getBool(_setupCompleteKey) ?? _setupComplete;
      }
      final storedTheme = await preferences.getString(_themeModeKey);
      themeMode = switch (storedTheme) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
      navBarStyle = await preferences.getString(_navBarStyleKey) == 'full_width'
          ? PixelNavBarStyle.fullWidth
          : PixelNavBarStyle.floating;
      navBarCompactMode = await preferences.getBool(_navBarCompactKey) ?? false;
      navBarCornerRadius = (await preferences.getDouble(_navBarRadiusKey) ?? 32)
          .clamp(0, 60);
      libraryCompactMode =
          await preferences.getBool(_libraryCompactKey) ?? false;
      _favoriteSongIds.addAll(
        await preferences.getStringList(_favoritesKey) ?? const [],
      );
      _playbackHistoryIds.addAll(
        await preferences.getStringList(_playbackHistoryKey) ?? const [],
      );
      searchHistory.addAll(
        await preferences.getStringList(_searchHistoryKey) ?? const [],
      );
      storedPlaylists = await preferences.getString(_playlistsKey);
      final storedCounts = await preferences.getString(_playCountsKey);
      if (storedCounts != null) {
        final decoded = Map<String, dynamic>.from(
          jsonDecode(storedCounts) as Map,
        );
        _playCounts.addAll(
          decoded.map((id, count) => MapEntry(id, count as int)),
        );
      }
      final storedEngagements = await preferences.getString(_engagementsKey);
      if (storedEngagements != null) {
        final decoded = Map<String, dynamic>.from(
          jsonDecode(storedEngagements) as Map,
        );
        for (final entry in decoded.entries) {
          final data = Map<String, dynamic>.from(entry.value as Map);
          _totalPlayedMs[entry.key] =
              (data['durationMs'] as num?)?.toInt() ?? 0;
          _lastPlayedAtMs[entry.key] =
              (data['lastPlayedAtMs'] as num?)?.toInt() ?? 0;
        }
      }
      final storedEvents = await preferences.getString(_playbackEventsKey);
      if (storedEvents != null) {
        final decoded = jsonDecode(storedEvents) as List<dynamic>;
        _playbackEvents.addAll(
          decoded.map(
            (item) =>
                PlaybackEvent.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        );
      }
      final storedSettings = await preferences.getString(_settingsKey);
      if (storedSettings != null) {
        _settings.addAll(
          Map<String, dynamic>.from(jsonDecode(storedSettings) as Map),
        );
      }
      selectedTab = switch (stringSetting('behavior_launch_tab', 'Home')) {
        'Search' => 1,
        'Library' => 2,
        _ => 0,
      };
      storedQueue = await preferences.getStringList(_queueKey) ?? const [];
      storedCurrentSong = await preferences.getString(_currentSongKey);
      storedPositionMs = await preferences.getInt(_positionKey) ?? 0;
    } catch (_) {
      // Tests and unsupported hosts can run without a preferences backend.
    }

    if (platformServicesEnabled) {
      await _configureAudioSession();
      if (boolSetting('account_google_drive_connected', false)) {
        await GoogleDriveAuthService.instance.restore(
          serverClientId: stringSetting('google_drive_web_client_id', ''),
        );
      }
    }
    await refreshLibrary(notify: false);
    _restorePlaylists(storedPlaylists);
    if (boolSetting('behavior_resume_playback', true) &&
        storedCurrentSong != null) {
      final byId = {for (final song in songs) song.id: song};
      queue = storedQueue
          .map((id) => byId[id])
          .whereType<Song>()
          .toList(growable: false);
      currentSong = byId[storedCurrentSong];
      position = Duration(milliseconds: storedPositionMs);
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.music());
      _playerSubscriptions
        ..add(
          session.becomingNoisyEventStream.listen((_) {
            if (boolSetting('playback_pause_on_headphones_disconnect', true) &&
                isPlaying) {
              togglePlayPause();
            }
          }),
        )
        ..add(
          session.interruptionEventStream.listen((event) {
            if (!event.begin || !isPlaying) return;
            if (event.type == AudioInterruptionType.pause ||
                event.type == AudioInterruptionType.unknown) {
              togglePlayPause();
            }
          }),
        );
    } catch (_) {
      // Audio focus is only available on supported device hosts.
    }
  }

  Future<void> refreshLibrary({bool notify = true}) async {
    libraryLoading = true;
    libraryError = null;
    if (notify) notifyListeners();
    var localSongs = const <Song>[];
    try {
      localSongs = await (_musicLibrary ??= MediaStoreMusicLibrary()).loadSongs(
        allowedDirectory: stringSetting('library_music_folders', ''),
      );
      final minimumDurationMs = doubleSetting(
        'library_min_song_duration_ms',
        0,
      ).round();
      final blockedDirectories = stringListSetting(
        'library_blocked_directories',
        const [],
      );
      localSongs = localSongs
          .where(
            (song) =>
                song.duration.inMilliseconds >= minimumDurationMs &&
                !_isInBlockedDirectory(song.path, blockedDirectories),
          )
          .toList(growable: false);
    } catch (error) {
      libraryError = error;
    } finally {
      songs = [...localSongs, ..._cachedGoogleDriveSongs()];
      libraryLoading = false;
      if (notify) notifyListeners();
      if (boolSetting('auto_scan_lrc_files', true) && localSongs.isNotEmpty) {
        unawaited(LyricsService.instance.scanAndAssignLocalFiles(localSongs));
      }
    }
  }

  Future<MetadataWriteResult> batchEditGenre(
    Iterable<Song> selectedSongs,
    String genre,
  ) async {
    final requested = selectedSongs.toList(growable: false);
    final result = await const SongMetadataWriter().writeGenre(
      requested,
      genre,
    );
    if (result.updatedSongIds.isEmpty) return result;

    final normalizedGenre = genre.trim();
    Song replace(Song song) => result.updatedSongIds.contains(song.id)
        ? song.copyWith(genre: normalizedGenre)
        : song;

    songs = songs.map(replace).toList(growable: false);
    queue = queue.map(replace).toList(growable: false);
    final active = currentSong;
    if (active != null) currentSong = replace(active);
    playlists = [
      for (final playlist in playlists)
        playlist.copyWith(
          songs: playlist.songs.map(replace).toList(growable: false),
        ),
    ];
    _persistPlaylists();
    notifyListeners();
    return result;
  }

  bool _isInBlockedDirectory(String? path, List<String> blockedDirectories) {
    if (path == null || path.isEmpty || blockedDirectories.isEmpty) {
      return false;
    }
    final normalizedPath = path.replaceAll('\\', '/').toLowerCase();
    for (final directory in blockedDirectories) {
      final normalizedDirectory = directory
          .replaceAll('\\', '/')
          .replaceFirst(RegExp(r'/+$'), '')
          .toLowerCase();
      if (normalizedDirectory.isEmpty) continue;
      if (normalizedPath == normalizedDirectory ||
          normalizedPath.startsWith('$normalizedDirectory/')) {
        return true;
      }
    }
    return false;
  }

  void replaceGoogleDriveLibrary(
    List<GoogleDriveAudioFile> files, {
    required String accessToken,
  }) {
    _settings['google_drive_files_json'] = jsonEncode(
      files.map((file) => file.toJson()).toList(growable: false),
    );
    _persistSettings();
    songs = [
      ...songs.where((song) => song.source != SongSource.googleDrive),
      ..._googleDriveSongs(files, accessToken),
    ];
    libraryError = null;
    notifyListeners();
  }

  void clearGoogleDriveLibrary() {
    _settings.remove('google_drive_files_json');
    _persistSettings();
    songs = songs
        .where((song) => song.source != SongSource.googleDrive)
        .toList(growable: false);
    notifyListeners();
  }

  List<Song> _cachedGoogleDriveSongs() {
    final raw = stringSetting('google_drive_files_json', '');
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final files = decoded
          .whereType<Map>()
          .map(
            (item) =>
                GoogleDriveAudioFile.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
      return _googleDriveSongs(
        files,
        GoogleDriveAuthService.instance.currentSession?.accessToken,
      );
    } on Object {
      return const [];
    }
  }

  List<Song> _googleDriveSongs(
    List<GoogleDriveAudioFile> files,
    String? accessToken,
  ) {
    final api = accessToken == null
        ? null
        : GoogleDriveApiService(accessToken: accessToken);
    return [
      for (final file in files)
        Song(
          id: 'gdrive:${file.id}',
          title: file.title,
          artist: file.artist,
          album: 'Google Drive',
          genre: 'Google Drive',
          duration: Duration.zero,
          colors: _googleDriveColors(file.id),
          contentUri: api?.streamUri(file.id).toString(),
          dateAdded: file.modifiedTime,
          dateModified: file.modifiedTime,
          mimeType: file.mimeType,
          fileSize: file.size,
          playbackHeaders: accessToken == null
              ? const {}
              : {'Authorization': 'Bearer $accessToken'},
          source: SongSource.googleDrive,
        ),
    ];
  }

  List<Color> _googleDriveColors(String seed) {
    var hash = 0x811C9DC5;
    for (final unit in seed.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    final hue = (hash % 360).toDouble();
    return [
      HSVColor.fromAHSV(1, hue, .54, .82).toColor(),
      HSVColor.fromAHSV(1, (hue + 38) % 360, .72, .38).toColor(),
    ];
  }

  void _persist(Future<void>? operation) {
    if (operation != null) {
      unawaited(operation);
    }
  }

  void _persistEngagements() {
    final encoded = <String, dynamic>{
      for (final id in {..._totalPlayedMs.keys, ..._lastPlayedAtMs.keys})
        id: {
          'durationMs': _totalPlayedMs[id] ?? 0,
          'lastPlayedAtMs': _lastPlayedAtMs[id] ?? 0,
        },
    };
    _persist(_preferences?.setString(_engagementsKey, jsonEncode(encoded)));
  }

  void _persistPlaybackEvents() {
    if (_playbackEvents.length > 5000) {
      _playbackEvents.removeRange(0, _playbackEvents.length - 5000);
    }
    _persist(
      _preferences?.setString(
        _playbackEventsKey,
        jsonEncode(_playbackEvents.map((event) => event.toJson()).toList()),
      ),
    );
  }

  void completeSetup() {
    _setupComplete = true;
    _persist(_preferences?.setBool(_setupCompleteKey, true));
    notifyListeners();
  }

  void resetSetup() {
    _setupComplete = false;
    _persist(_preferences?.setBool(_setupCompleteKey, false));
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _persist(
      _preferences?.setString(_themeModeKey, switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      }),
    );
    notifyListeners();
  }

  void selectTab(int index) {
    if (selectedTab == index && index == 1) {
      notifyListeners();
      return;
    }
    selectedTab = index;
    notifyListeners();
  }

  void setNavBarStyle(PixelNavBarStyle style) {
    navBarStyle = style;
    _persist(
      _preferences?.setString(
        _navBarStyleKey,
        style == PixelNavBarStyle.fullWidth ? 'full_width' : 'default',
      ),
    );
    notifyListeners();
  }

  void setNavBarCompactMode(bool compact) {
    navBarCompactMode = compact;
    _persist(_preferences?.setBool(_navBarCompactKey, compact));
    notifyListeners();
  }

  void setNavBarCornerRadius(double radius) {
    navBarCornerRadius = radius.clamp(0, 60);
    _persist(_preferences?.setDouble(_navBarRadiusKey, navBarCornerRadius));
    notifyListeners();
  }

  void setLibraryCompactMode(bool compact) {
    libraryCompactMode = compact;
    _persist(_preferences?.setBool(_libraryCompactKey, compact));
    notifyListeners();
  }

  void addSearchHistory(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    searchHistory
      ..removeWhere((item) => item.toLowerCase() == clean.toLowerCase())
      ..insert(0, clean);
    if (searchHistory.length > 20) {
      searchHistory.removeRange(20, searchHistory.length);
    }
    _persist(_preferences?.setStringList(_searchHistoryKey, searchHistory));
    notifyListeners();
  }

  void removeSearchHistory(String query) {
    searchHistory.remove(query);
    _persist(_preferences?.setStringList(_searchHistoryKey, searchHistory));
    notifyListeners();
  }

  void clearSearchHistory() {
    searchHistory.clear();
    _persist(_preferences?.setStringList(_searchHistoryKey, searchHistory));
    notifyListeners();
  }

  void setBoolSetting(String key, bool value) {
    _settings[key] = value;
    _persistSettings();
    notifyListeners();
  }

  void setStringSetting(String key, String value) {
    _settings[key] = value;
    _persistSettings();
    notifyListeners();
  }

  List<String> stringListSetting(String key, List<String> fallback) {
    final value = _settings[key];
    if (value is! List) return List<String>.of(fallback);
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  void setStringListSetting(String key, Iterable<String> values) {
    _settings[key] = values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    _persistSettings();
    notifyListeners();
  }

  void setLaunchTab(String tab) {
    _settings['behavior_launch_tab'] = tab;
    selectedTab = switch (tab) {
      'Search' => 1,
      'Library' => 2,
      _ => 0,
    };
    _persistSettings();
    notifyListeners();
  }

  void setDoubleSetting(String key, double value) {
    _settings[key] = value;
    _persistSettings();
    notifyListeners();
  }

  void setEqualizerEnabled(bool enabled) {
    setBoolSetting('equalizer_enabled', enabled);
    final equalizer = _equalizer;
    final loudness = _loudnessEnhancer;
    if (equalizer != null) unawaited(equalizer.setEnabled(enabled));
    if (loudness != null) unawaited(loudness.setEnabled(enabled));
  }

  void setEqualizerBands(List<double> gains) {
    _settings['equalizer_bands'] = gains;
    _persistSettings();
    unawaited(_applyEqualizerSettings());
    notifyListeners();
  }

  void setEqualizerLoudness(double value) {
    _settings['equalizer_loudness'] = value;
    _persistSettings();
    final loudness = _loudnessEnhancer;
    if (loudness != null) unawaited(loudness.setTargetGain(value * 12));
    notifyListeners();
  }

  void _persistSettings() {
    _persist(_preferences?.setString(_settingsKey, jsonEncode(_settings)));
  }

  void createPlaylist(
    String name,
    Iterable<String> songIds, {
    String? coverPath,
    int? coverColorValue,
    String? coverIconName,
    String coverShape = 'smoothRect',
    double? coverShapeDetail1,
    double? coverShapeDetail2,
    double? coverShapeDetail3,
    double? coverShapeDetail4,
    String? smartRule,
  }) {
    final cleanName = name.trim().isEmpty ? 'New playlist' : name.trim();
    final selectedIds = smartRule == null
        ? songIds.toSet()
        : _smartPlaylistSongIds(smartRule, limit: 50).toSet();
    final selectedSongs = songs
        .where((song) => selectedIds.contains(song.id))
        .toList(growable: false);
    playlists = [
      ...playlists,
      Playlist(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: cleanName,
        songs: selectedSongs,
        coverPath: coverPath,
        coverColorValue: coverColorValue,
        coverIconName: coverIconName,
        coverShape: coverShape,
        coverShapeDetail1: coverShapeDetail1,
        coverShapeDetail2: coverShapeDetail2,
        coverShapeDetail3: coverShapeDetail3,
        coverShapeDetail4: coverShapeDetail4,
      ),
    ];
    _persistPlaylists();
    notifyListeners();
  }

  List<String> _smartPlaylistSongIds(String rule, {required int limit}) {
    if (songs.isEmpty) return const [];
    final safeLimit = limit.clamp(1, songs.length);
    final now = DateTime.now();
    final selected = switch (rule) {
      'top_played' =>
        [...songs]..sort((a, b) {
          final playOrder = (_playCounts[b.id] ?? 0).compareTo(
            _playCounts[a.id] ?? 0,
          );
          if (playOrder != 0) return playOrder;
          final durationOrder = (_totalPlayedMs[b.id] ?? 0).compareTo(
            _totalPlayedMs[a.id] ?? 0,
          );
          if (durationOrder != 0) return durationOrder;
          return (_lastPlayedAtMs[b.id] ?? 0).compareTo(
            _lastPlayedAtMs[a.id] ?? 0,
          );
        }),
      'recently_played' =>
        [...songs.where((song) => (_lastPlayedAtMs[song.id] ?? 0) > 0)]..sort(
          (a, b) => (_lastPlayedAtMs[b.id] ?? 0).compareTo(
            _lastPlayedAtMs[a.id] ?? 0,
          ),
        ),
      'forgotten_favorites' =>
        [
          ...songs.where((song) {
            if (!_favoriteSongIds.contains(song.id)) return false;
            final lastPlayed = _lastPlayedDate(song.id);
            return lastPlayed == null ||
                now.difference(lastPlayed) > const Duration(days: 30);
          }),
        ]..sort((a, b) {
          final aPlayed = _lastPlayedAtMs[a.id] ?? 0;
          final bPlayed = _lastPlayedAtMs[b.id] ?? 0;
          final playOrder = aPlayed.compareTo(bPlayed);
          return playOrder != 0
              ? playOrder
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        }),
      'new_gems' =>
        [...songs.where((song) => (_playCounts[song.id] ?? 0) <= 2)]
          ..sort((a, b) {
            final dateOrder = (b.dateAdded ?? DateTime(1970)).compareTo(
              a.dateAdded ?? DateTime(1970),
            );
            return dateOrder != 0
                ? dateOrder
                : (_playCounts[a.id] ?? 0).compareTo(_playCounts[b.id] ?? 0);
          }),
      _ => <Song>[],
    };
    final fallback = [...songs]
      ..sort(
        (a, b) => (b.dateAdded ?? DateTime(1970)).compareTo(
          a.dateAdded ?? DateTime(1970),
        ),
      );
    final resolved = selected.isEmpty ? fallback : selected;
    return resolved
        .take(safeLimit)
        .map((song) => song.id)
        .toSet()
        .toList(growable: false);
  }

  void renamePlaylist(String playlistId, String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    playlists = [
      for (final playlist in playlists)
        if (playlist.id == playlistId)
          playlist.copyWith(name: cleanName)
        else
          playlist,
    ];
    _persistPlaylists();
    notifyListeners();
  }

  void deletePlaylist(String playlistId) {
    playlists = playlists
        .where((playlist) => playlist.id != playlistId)
        .toList(growable: false);
    _persistPlaylists();
    notifyListeners();
  }

  void addSongsToPlaylist(String playlistId, Iterable<String> songIds) {
    final ids = songIds.toSet();
    if (ids.isEmpty) return;
    final byId = {for (final song in songs) song.id: song};
    playlists = [
      for (final playlist in playlists)
        if (playlist.id == playlistId)
          playlist.copyWith(
            songs: [
              ...playlist.songs,
              for (final id in ids)
                if (!playlist.songs.any((song) => song.id == id) &&
                    byId[id] != null)
                  byId[id]!,
            ],
          )
        else
          playlist,
    ];
    _persistPlaylists();
    notifyListeners();
  }

  void removeSongFromPlaylist(String playlistId, String songId) {
    playlists = [
      for (final playlist in playlists)
        if (playlist.id == playlistId)
          playlist.copyWith(
            songs: playlist.songs
                .where((song) => song.id != songId)
                .toList(growable: false),
          )
        else
          playlist,
    ];
    _persistPlaylists();
    notifyListeners();
  }

  void reorderPlaylistSongs(String playlistId, int oldIndex, int newIndex) {
    final target = playlists.where((playlist) => playlist.id == playlistId);
    if (target.isEmpty) return;
    final ordered = List<Song>.of(target.first.songs);
    if (oldIndex < 0 ||
        oldIndex >= ordered.length ||
        newIndex < 0 ||
        newIndex >= ordered.length) {
      return;
    }
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    playlists = [
      for (final playlist in playlists)
        if (playlist.id == playlistId)
          playlist.copyWith(songs: ordered)
        else
          playlist,
    ];
    _persistPlaylists();
    notifyListeners();
  }

  void _restorePlaylists(String? encoded) {
    if (encoded == null || encoded.isEmpty) return;
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      final byId = {for (final song in songs) song.id: song};
      playlists = decoded
          .map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            final ids = List<String>.from(map['songIds'] as List? ?? const []);
            return Playlist(
              id: map['id'] as String,
              name: map['name'] as String,
              songs: ids.map((id) => byId[id]).whereType<Song>().toList(),
              coverPath: map['coverPath'] as String?,
              coverColorValue: (map['coverColorValue'] as num?)?.toInt(),
              coverIconName: map['coverIconName'] as String?,
              coverShape: map['coverShape'] as String? ?? 'smoothRect',
              coverShapeDetail1: (map['coverShapeDetail1'] as num?)?.toDouble(),
              coverShapeDetail2: (map['coverShapeDetail2'] as num?)?.toDouble(),
              coverShapeDetail3: (map['coverShapeDetail3'] as num?)?.toDouble(),
              coverShapeDetail4: (map['coverShapeDetail4'] as num?)?.toDouble(),
            );
          })
          .toList(growable: false);
    } catch (_) {
      playlists = const [];
    }
  }

  void _persistPlaylists() {
    final encoded = jsonEncode([
      for (final playlist in playlists)
        {
          'id': playlist.id,
          'name': playlist.name,
          'songIds': playlist.songs.map((song) => song.id).toList(),
          'coverPath': playlist.coverPath,
          'coverColorValue': playlist.coverColorValue,
          'coverIconName': playlist.coverIconName,
          'coverShape': playlist.coverShape,
          'coverShapeDetail1': playlist.coverShapeDetail1,
          'coverShapeDetail2': playlist.coverShapeDetail2,
          'coverShapeDetail3': playlist.coverShapeDetail3,
          'coverShapeDetail4': playlist.coverShapeDetail4,
        },
    ]);
    _persist(_preferences?.setString(_playlistsKey, encoded));
  }

  String createBackupJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'pixelplay_flutter_backup',
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'setupComplete': _setupComplete,
      'themeMode': themeMode.name,
      'favorites': _favoriteSongIds.toList(),
      'playbackHistory': _playbackHistoryIds,
      'playCounts': _playCounts,
      'engagements': {
        for (final id in {..._totalPlayedMs.keys, ..._lastPlayedAtMs.keys})
          id: {
            'durationMs': _totalPlayedMs[id] ?? 0,
            'lastPlayedAtMs': _lastPlayedAtMs[id] ?? 0,
          },
      },
      'playbackEvents': _playbackEvents.map((event) => event.toJson()).toList(),
      'settings': _settings,
      'playlists': [
        for (final playlist in playlists)
          {
            'id': playlist.id,
            'name': playlist.name,
            'songIds': playlist.songs.map((song) => song.id).toList(),
            'coverPath': playlist.coverPath,
            'coverColorValue': playlist.coverColorValue,
            'coverIconName': playlist.coverIconName,
            'coverShape': playlist.coverShape,
            'coverShapeDetail1': playlist.coverShapeDetail1,
            'coverShapeDetail2': playlist.coverShapeDetail2,
            'coverShapeDetail3': playlist.coverShapeDetail3,
            'coverShapeDetail4': playlist.coverShapeDetail4,
          },
      ],
    });
  }

  Future<void> restoreBackupJson(String encoded) async {
    final backup = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    if (backup['format'] != 'pixelplay_flutter_backup') {
      throw const FormatException('Unsupported PixelPlay backup');
    }
    _setupComplete = backup['setupComplete'] as bool? ?? _setupComplete;
    themeMode = switch (backup['themeMode']) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    _favoriteSongIds
      ..clear()
      ..addAll(List<String>.from(backup['favorites'] as List? ?? const []));
    _playbackHistoryIds
      ..clear()
      ..addAll(
        List<String>.from(backup['playbackHistory'] as List? ?? const []),
      );
    _playCounts
      ..clear()
      ..addAll(
        Map<String, dynamic>.from(
          backup['playCounts'] as Map? ?? const {},
        ).map((id, count) => MapEntry(id, count as int)),
      );
    _totalPlayedMs.clear();
    _lastPlayedAtMs.clear();
    final engagements = Map<String, dynamic>.from(
      backup['engagements'] as Map? ?? const {},
    );
    for (final entry in engagements.entries) {
      final data = Map<String, dynamic>.from(entry.value as Map);
      _totalPlayedMs[entry.key] = (data['durationMs'] as num?)?.toInt() ?? 0;
      _lastPlayedAtMs[entry.key] =
          (data['lastPlayedAtMs'] as num?)?.toInt() ?? 0;
    }
    _playbackEvents
      ..clear()
      ..addAll(
        (backup['playbackEvents'] as List? ?? const []).map(
          (item) =>
              PlaybackEvent.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
    _settings
      ..clear()
      ..addAll(
        Map<String, dynamic>.from(backup['settings'] as Map? ?? const {}),
      );
    _restorePlaylists(jsonEncode(backup['playlists'] ?? const []));

    final preferences = _preferences;
    if (preferences != null) {
      await Future.wait([
        preferences.setBool(_setupCompleteKey, _setupComplete),
        preferences.setString(_themeModeKey, themeMode.name),
        preferences.setStringList(_favoritesKey, _favoriteSongIds.toList()),
        preferences.setStringList(_playbackHistoryKey, _playbackHistoryIds),
        preferences.setString(_playCountsKey, jsonEncode(_playCounts)),
        preferences.setString(_engagementsKey, jsonEncode(engagements)),
        preferences.setString(
          _playbackEventsKey,
          jsonEncode(_playbackEvents.map((event) => event.toJson()).toList()),
        ),
        preferences.setString(_settingsKey, jsonEncode(_settings)),
        preferences.setString(
          _playlistsKey,
          jsonEncode(backup['playlists'] ?? const []),
        ),
      ]);
    }
    notifyListeners();
  }

  void playSong(Song song, {List<Song>? fromQueue}) {
    _dismissUndoTimer?.cancel();
    _dismissedSong = null;
    _dismissedQueue = const [];
    _dismissedPosition = Duration.zero;
    showDismissUndoBar = false;
    final previousSong = currentSong;
    if (previousSong != null && position > Duration.zero) {
      _totalPlayedMs.update(
        previousSong.id,
        (duration) => duration + position.inMilliseconds,
        ifAbsent: () => position.inMilliseconds,
      );
      if (_playbackEvents.isNotEmpty &&
          _playbackEvents.last.songId == previousSong.id) {
        _playbackEvents[_playbackEvents.length - 1] = _playbackEvents.last
            .copyWith(listenedDuration: position);
      }
    }
    currentSong = song;
    if (_preferences != null) {
      unawaited(_prefetchLyrics(song));
    }
    _playbackEvents.add(
      PlaybackEvent(
        songId: song.id,
        startedAt: DateTime.now(),
        listenedDuration: Duration.zero,
      ),
    );
    queue = fromQueue ?? songs;
    _playbackHistoryIds
      ..remove(song.id)
      ..insert(0, song.id);
    if (_playbackHistoryIds.length > 64) {
      _playbackHistoryIds.removeRange(64, _playbackHistoryIds.length);
    }
    _persist(
      _preferences?.setStringList(_playbackHistoryKey, _playbackHistoryIds),
    );
    _playCounts.update(song.id, (count) => count + 1, ifAbsent: () => 1);
    _lastPlayedAtMs[song.id] = DateTime.now().millisecondsSinceEpoch;
    _persist(_preferences?.setString(_playCountsKey, jsonEncode(_playCounts)));
    _persistEngagements();
    _persistPlaybackEvents();
    position = Duration.zero;
    isPlaying = true;
    if (song.isPlayable) {
      final cast = GoogleCastService.instance;
      if (cast.connected) {
        final player = _audioPlayer;
        if (player != null) unawaited(player.pause());
        unawaited(cast.loadSong(song));
      } else {
        unawaited(_loadAndPlay(song, queue));
      }
      // Probe real bitrate/sampleRate/mimeType asynchronously, same as Kotlin's
      // MediaControllerSyncStateHolder.probeAudioMetadata().
      unawaited(_probeAudioMeta(song));
    } else {
      _startTimer();
    }
    _persistPlaybackSession();
    notifyListeners();
  }

  Future<void> _prefetchLyrics(Song song) async {
    try {
      await LyricsService.instance.lyricsFor(
        song,
        preference: LyricsSourcePreference.fromSetting(
          stringSetting('library_lyrics_source_priority', 'Embedded first'),
        ),
        includeRemote: true,
      );
    } catch (_) {
      // Lyrics are optional; the pickup flow remains available on failure.
    }
  }

  void playShuffled(List<Song> songs) {
    if (songs.isEmpty) return;
    shuffleEnabled = true;
    final shuffled = [...songs]..shuffle();
    playSong(shuffled.first, fromQueue: shuffled);
  }

  Future<void> regenerateDailyMixWithPrompt(String prompt) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty || songs.isEmpty || dailyMixGenerating) return;
    final apiKey = stringSetting('gemini_api_key', '');
    final model = stringSetting('gemini_model', GeminiAiClient.defaultModel);
    dailyMixGenerating = true;
    dailyMixAiError = null;
    dailyMixAiStatus = 'Reading your library…';
    notifyListeners();
    try {
      final candidates = songs
          .take(300)
          .map((song) {
            return {
              'id': song.id,
              'title': song.title,
              'artist': song.artist,
              'album': song.album,
              'genre': song.genre,
              'year': song.year,
            };
          })
          .toList(growable: false);
      dailyMixAiStatus = 'Curating your mix…';
      notifyListeners();
      final response = await _geminiAiClient.generateContent(
        apiKey: apiKey,
        model: model,
        temperature: .45,
        maxOutputTokens: 2048,
        systemPrompt:
            'You curate a music playlist using only the supplied library. '
            'Return only a JSON array of unique song id strings, in playback '
            'order. Never invent ids and choose at most 30.',
        prompt:
            'Listener request: $cleanPrompt\n'
            'Library JSON:\n${jsonEncode(candidates)}',
      );
      final cleanJson = response
          .replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*```$'), '')
          .trim();
      final decoded = jsonDecode(cleanJson);
      if (decoded is! List) {
        throw const FormatException('Gemini did not return a song list.');
      }
      final byId = {for (final song in songs) song.id: song};
      final selected = <Song>[];
      final seen = <String>{};
      for (final value in decoded) {
        final id = value.toString();
        final song = byId[id];
        if (song != null && seen.add(id)) selected.add(song);
        if (selected.length >= 30) break;
      }
      if (selected.isEmpty) {
        throw const FormatException(
          'Gemini could not match songs from this library.',
        );
      }
      _dailyMixOverride = selected;
      dailyMixAiStatus = 'Your new mix is ready';
    } on GeminiApiException catch (error) {
      dailyMixAiError = error.message;
      dailyMixAiStatus = null;
    } on FormatException catch (error) {
      dailyMixAiError = error.message;
      dailyMixAiStatus = null;
    } finally {
      dailyMixGenerating = false;
      notifyListeners();
    }
  }

  void resetDailyMixPrompt() {
    _dailyMixOverride = null;
    dailyMixAiStatus = null;
    dailyMixAiError = null;
    notifyListeners();
  }

  /// Probes real audio metadata (bitrate, sampleRate, mimeType) for [song] via
  /// the native [AudioMetaService] (MediaMetadataRetriever), then patches
  /// [currentSong] if the song is still the active one.
  ///
  /// Matches Kotlin's MediaControllerSyncStateHolder.probeAudioMetadata().
  Future<void> _probeAudioMeta(Song song) async {
    if (song.source == SongSource.googleDrive) return;
    final uri = song.contentUri ?? song.path;
    if (uri == null || uri.isEmpty) return;
    final meta = await AudioMetaService.fetch(uri);
    if (meta == null) return;
    // Only update if this song is still playing
    if (currentSong?.id != song.id) return;
    final needsUpdate =
        (meta.mimeType != null && meta.mimeType != song.mimeType) ||
        (meta.bitrate != null && meta.bitrate != song.bitrate) ||
        (meta.sampleRate != null && meta.sampleRate != song.sampleRate);
    if (!needsUpdate) return;
    currentSong = song.copyWith(
      mimeType: meta.mimeType,
      bitrate: meta.bitrate,
      sampleRate: meta.sampleRate,
    );
    notifyListeners();
  }

  void togglePlayPause() {
    if (currentSong == null) {
      if (songs.isNotEmpty) playSong(songs.first);
      return;
    }
    isPlaying = !isPlaying;
    final cast = GoogleCastService.instance;
    if (cast.connected) {
      unawaited(isPlaying ? cast.play() : cast.pause());
      _persistPlaybackSession();
      notifyListeners();
      return;
    }
    final player = _audioPlayer;
    if (currentSong!.isPlayable) {
      if (player == null && isPlaying) {
        unawaited(
          _loadAndPlay(
            currentSong!,
            queue.isEmpty ? [currentSong!] : queue,
            initialPosition: position,
          ),
        );
      } else if (player != null) {
        unawaited(isPlaying ? player.play() : player.pause());
      }
    } else {
      isPlaying ? _startTimer() : _progressTimer?.cancel();
    }
    _persistPlaybackSession();
    notifyListeners();
  }

  void toggleShuffle() {
    shuffleEnabled = !shuffleEnabled;
    final player = _audioPlayer;
    if (player != null) {
      unawaited(player.setShuffleModeEnabled(shuffleEnabled));
      if (shuffleEnabled) unawaited(player.shuffle());
    }
    notifyListeners();
  }

  bool isFavorite(Song song) => _favoriteSongIds.contains(song.id);

  void toggleFavorite() {
    final song = currentSong;
    if (song == null) return;
    toggleFavoriteFor(song);
  }

  void toggleFavoriteFor(Song song) {
    if (!_favoriteSongIds.add(song.id)) {
      _favoriteSongIds.remove(song.id);
    }
    _persist(
      _preferences?.setStringList(_favoritesKey, _favoriteSongIds.toList()),
    );
    notifyListeners();
  }

  void setFavoriteSongs(Iterable<Song> targetSongs, bool favorite) {
    for (final song in targetSongs) {
      favorite
          ? _favoriteSongIds.add(song.id)
          : _favoriteSongIds.remove(song.id);
    }
    _persist(
      _preferences?.setStringList(_favoritesKey, _favoriteSongIds.toList()),
    );
    notifyListeners();
  }

  void cycleRepeatMode() {
    repeatMode = (repeatMode + 1) % 3;
    final player = _audioPlayer;
    if (player != null) {
      unawaited(
        player.setLoopMode(switch (repeatMode) {
          1 => LoopMode.one,
          2 => LoopMode.all,
          _ => LoopMode.off,
        }),
      );
    }
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= queue.length ||
        newIndex < 0 ||
        newIndex > queue.length) {
      return;
    }
    final reordered = List<Song>.of(queue);
    if (newIndex > oldIndex) newIndex -= 1;
    final song = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, song);
    queue = reordered;
    if (_audioPlayer != null &&
        _audioQueue.length == queue.length &&
        queue.every((song) => song.isPlayable)) {
      unawaited(_audioPlayer!.moveAudioSource(oldIndex, newIndex));
      _audioQueue = List<Song>.of(queue);
    }
    notifyListeners();
  }

  void addSongToQueue(Song song) {
    if (queue.isEmpty || currentSong == null) {
      queue = [song];
      notifyListeners();
      return;
    }
    if (queue.any((item) => item.id == song.id)) return;
    queue = [...queue, song];
    _reloadActiveQueue();
  }

  void addSongNextToQueue(Song song) {
    final active = currentSong;
    if (queue.isEmpty || active == null) {
      queue = [song];
      notifyListeners();
      return;
    }
    final updated = List<Song>.of(queue)
      ..removeWhere((item) => item.id == song.id);
    final currentIndex = updated.indexWhere((item) => item.id == active.id);
    updated.insert(currentIndex < 0 ? 0 : currentIndex + 1, song);
    queue = updated;
    _reloadActiveQueue();
  }

  void _reloadActiveQueue() {
    final active = currentSong;
    final player = _audioPlayer;
    if (active == null || player == null || !active.isPlayable) {
      notifyListeners();
      return;
    }
    final currentPosition = position;
    final shouldPlay = isPlaying;
    unawaited(
      _loadAndPlay(
        active,
        queue,
        initialPosition: currentPosition,
        autoPlay: shouldPlay,
      ),
    );
    notifyListeners();
  }

  void seek(double fraction) {
    final song = currentSong;
    if (song == null) return;
    position = Duration(
      milliseconds: (song.duration.inMilliseconds * fraction.clamp(0, 1))
          .round(),
    );
    final cast = GoogleCastService.instance;
    if (cast.connected) {
      unawaited(cast.seek(position));
    } else if (_audioPlayer != null && song.isPlayable) {
      unawaited(_audioPlayer!.seek(position));
    }
    _persistPlaybackSession();
    notifyListeners();
  }

  void skipNext() {
    final song = currentSong;
    if (song == null || queue.isEmpty) return;
    final index = queue.indexWhere((item) => item.id == song.id);
    if (repeatMode == 1) {
      seek(0);
      return;
    }
    if (sleepAtEndOfTrack) {
      cancelSleepTimer();
      isPlaying = false;
      _progressTimer?.cancel();
      final cast = GoogleCastService.instance;
      if (cast.connected) {
        unawaited(cast.pause());
      } else if (_audioPlayer != null) {
        unawaited(_audioPlayer!.pause());
      }
      position = song.duration;
      notifyListeners();
      return;
    }
    final nextIndex = shuffleEnabled
        ? (DateTime.now().millisecondsSinceEpoch % queue.length)
        : index < queue.length - 1
        ? index + 1
        : repeatMode == 2
        ? 0
        : index;
    if (nextIndex == index && repeatMode == 0) {
      isPlaying = false;
      position = song.duration;
      _progressTimer?.cancel();
      notifyListeners();
      return;
    }
    playSong(queue[nextIndex], fromQueue: queue);
  }

  void skipPrevious() {
    final song = currentSong;
    if (song == null || queue.isEmpty) return;
    if (position > const Duration(seconds: 10) || repeatMode == 1) {
      seek(0);
      return;
    }
    final index = queue.indexWhere((item) => item.id == song.id);
    final previousIndex = index > 0
        ? index - 1
        : repeatMode == 2
        ? queue.length - 1
        : 0;
    if (previousIndex == index) {
      seek(0);
      return;
    }
    playSong(queue[previousIndex], fromQueue: queue);
  }

  void showFullPlayer() {
    if (currentSong == null) return;
    fullPlayerVisible = true;
    notifyListeners();
  }

  void hideFullPlayer() {
    fullPlayerVisible = false;
    notifyListeners();
  }

  void resumePlaybackOnThisDevice({
    required Duration remotePosition,
    required bool wasPlaying,
  }) {
    final song = currentSong;
    if (song == null) return;
    position = remotePosition;
    isPlaying = wasPlaying;
    if (song.isPlayable) {
      unawaited(
        _loadAndPlay(
          song,
          queue.isEmpty ? [song] : queue,
          initialPosition: remotePosition,
          autoPlay: wasPlaying,
        ),
      );
    } else if (wasPlaying) {
      _startTimer();
    }
    _persistPlaybackSession();
    notifyListeners();
  }

  bool dismissPlaylist() {
    final song = currentSong;
    if (song == null && queue.isEmpty) return false;

    _dismissedSong = song;
    _dismissedQueue = List<Song>.of(queue);
    _dismissedPosition = position;

    _progressTimer?.cancel();
    if (_audioPlayer != null) unawaited(_audioPlayer!.pause());
    currentSong = null;
    queue = const [];
    position = Duration.zero;
    isPlaying = false;
    fullPlayerVisible = false;
    showDismissUndoBar = true;
    _persistPlaybackSession();
    _dismissUndoTimer?.cancel();
    _dismissUndoTimer = Timer(dismissUndoDuration, clearDismissedPlaylist);
    notifyListeners();
    return true;
  }

  bool undoDismissPlaylist() {
    final song = _dismissedSong;
    if (song == null || _dismissedQueue.isEmpty) return false;

    currentSong = song;
    queue = List<Song>.of(_dismissedQueue);
    position = _dismissedPosition;
    isPlaying = true;
    fullPlayerVisible = false;
    _dismissedSong = null;
    _dismissedQueue = const [];
    _dismissedPosition = Duration.zero;
    showDismissUndoBar = false;
    _dismissUndoTimer?.cancel();
    if (song.isPlayable) {
      unawaited(_loadAndPlay(song, queue, initialPosition: position));
    } else {
      _startTimer();
    }
    notifyListeners();
    return true;
  }

  void clearDismissedPlaylist() {
    _dismissUndoTimer?.cancel();
    _dismissedSong = null;
    _dismissedQueue = const [];
    _dismissedPosition = Duration.zero;
    showDismissUndoBar = false;
    notifyListeners();
  }

  void setSleepTimer(Duration duration) {
    cancelSleepTimer(notify: false);
    sleepTimerEnd = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      sleepTimerEnd = null;
      if (isPlaying) togglePlayPause();
      _sleepTimerTicker?.cancel();
      notifyListeners();
    });
    _sleepTimerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
    notifyListeners();
  }

  void setSleepAtEndOfTrack() {
    cancelSleepTimer(notify: false);
    sleepAtEndOfTrack = true;
    notifyListeners();
  }

  void cancelSleepTimer({bool notify = true}) {
    _sleepTimer?.cancel();
    _sleepTimerTicker?.cancel();
    _sleepTimer = null;
    _sleepTimerTicker = null;
    sleepTimerEnd = null;
    sleepAtEndOfTrack = false;
    if (notify) notifyListeners();
  }

  void _startTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final song = currentSong;
      if (!isPlaying || song == null) return;
      if (position >= song.duration) {
        skipNext();
      } else {
        position += const Duration(seconds: 1);
      }
    });
  }

  AudioPlayer _ensureAudioPlayer() {
    final existing = _audioPlayer;
    if (existing != null) return existing;

    AndroidEqualizer? equalizer;
    AndroidLoudnessEnhancer? loudness;
    try {
      equalizer = AndroidEqualizer();
      loudness = AndroidLoudnessEnhancer();
      _equalizer = equalizer;
      _loudnessEnhancer = loudness;
    } catch (_) {}

    final player = AudioPlayer(
      audioPipeline: equalizer != null && loudness != null
          ? AudioPipeline(androidAudioEffects: [equalizer, loudness])
          : null,
    );
    _audioPlayer = player;
    _playerSubscriptions
      ..add(
        player.playingStream.listen((playing) {
          if (isPlaying == playing) return;
          isPlaying = playing;
          notifyListeners();
        }),
      )
      ..add(
        player.positionStream.listen((newPosition) {
          position = newPosition;
          if (newPosition.inSeconds != _lastPersistedPositionSecond &&
              newPosition.inSeconds % 5 == 0) {
            _lastPersistedPositionSecond = newPosition.inSeconds;
            _persistPlaybackSession();
          }
          final duration = currentSong?.duration;
          if (sleepAtEndOfTrack &&
              duration != null &&
              duration - newPosition <= const Duration(milliseconds: 350)) {
            unawaited(player.pause());
            position = duration;
            cancelSleepTimer(notify: false);
          }
        }),
      )
      ..add(
        player.currentIndexStream.listen((index) {
          if (index == null || index < 0 || index >= _audioQueue.length) return;
          final song = _audioQueue[index];
          if (currentSong?.id == song.id) return;
          currentSong = song;
          position = Duration.zero;
          notifyListeners();
        }),
      )
      ..add(
        player.processingStateStream.listen((state) {
          if (state != ProcessingState.completed || repeatMode != 0) return;
          isPlaying = false;
          notifyListeners();
        }),
      );
    return player;
  }

  Future<void> _loadAndPlay(
    Song song,
    List<Song> requestedQueue, {
    Duration initialPosition = Duration.zero,
    bool autoPlay = true,
  }) async {
    final playable = requestedQueue
        .where((item) => item.playbackUri != null)
        .toList(growable: false);
    final index = playable.indexWhere((item) => item.id == song.id);
    final uri = song.playbackUri;
    if (uri == null || index < 0) {
      isPlaying = false;
      notifyListeners();
      return;
    }

    try {
      final player = _ensureAudioPlayer();
      _progressTimer?.cancel();
      _audioQueue = playable;
      final containsGoogleDrive = playable.any(
        (item) => item.source == SongSource.googleDrive,
      );
      final freshGoogleDriveToken = containsGoogleDrive
          ? await GoogleDriveAuthService.instance.refreshAccessToken()
          : null;
      await player.setAudioSources(
        playable
            .map(
              (item) => AudioSource.uri(
                item.playbackUri!,
                headers:
                    item.source == SongSource.googleDrive &&
                        freshGoogleDriveToken != null
                    ? {'Authorization': 'Bearer $freshGoogleDriveToken'}
                    : item.playbackHeaders,
                tag: MediaItem(
                  id: item.id,
                  title: item.title,
                  artist: item.artist,
                  album: item.album,
                  duration: item.duration,
                  artUri: item.albumId != null
                      ? Uri.parse(
                          'content://media/external/audio/albumart/'
                          '${item.albumId}',
                        )
                      : (item.mediaStoreId != null
                          ? Uri.parse(
                              'content://media/external/audio/media/'
                              '${item.mediaStoreId}/albumart',
                            )
                          : null),
                ),
              ),
            )
            .toList(growable: false),
        initialIndex: index,
        initialPosition: initialPosition,
        shuffleOrder: DefaultShuffleOrder(),
      );
      try {
        await _applyEqualizerSettings();
      } catch (_) {}
      await player.setLoopMode(switch (repeatMode) {
        1 => LoopMode.one,
        2 => LoopMode.all,
        _ => LoopMode.off,
      });
      await player.setShuffleModeEnabled(shuffleEnabled);
      if (shuffleEnabled) await player.shuffle();
      if (autoPlay) {
        await player.play();
      } else {
        await player.pause();
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> _applyEqualizerSettings() async {
    final equalizer = _equalizer;
    final loudness = _loudnessEnhancer;
    if (equalizer == null || loudness == null) return;
    try {
      final enabled = boolSetting('equalizer_enabled', false);
      await equalizer.setEnabled(enabled);
      await loudness.setEnabled(enabled);
      await loudness.setTargetGain(doubleSetting('equalizer_loudness', .35) * 12);
      if (!enabled) return;
      final parameters = await equalizer.parameters;
      final desired = equalizerBands;
      for (var index = 0; index < parameters.bands.length; index++) {
        final desiredIndex = parameters.bands.length == 1
            ? 0
            : (index * (desired.length - 1) / (parameters.bands.length - 1))
                  .round();
        final gain = desired[desiredIndex].clamp(
          parameters.minDecibels,
          parameters.maxDecibels,
        );
        await parameters.bands[index].setGain(gain);
      }
    } catch (_) {
      // Audio effects are device- and decoder-dependent.
    }
  }

  void _persistPlaybackSession() {
    final preferences = _preferences;
    if (preferences == null) return;
    _persist(
      preferences.setStringList(
        _queueKey,
        queue.map((song) => song.id).toList(),
      ),
    );
    final song = currentSong;
    if (song != null) {
      _persist(preferences.setString(_currentSongKey, song.id));
      _persist(preferences.setInt(_positionKey, position.inMilliseconds));
    } else {
      _persist(preferences.remove(_currentSongKey));
      _persist(preferences.remove(_positionKey));
    }
  }

  void _syncGoogleCastState() {
    final cast = GoogleCastService.instance;
    if (!cast.connected) return;
    position = cast.remotePosition;
    if (isPlaying == cast.remoteIsPlaying) return;
    isPlaying = cast.remoteIsPlaying;
    _persistPlaybackSession();
    notifyListeners();
  }

  @override
  void dispose() {
    final song = currentSong;
    if (song != null && position > Duration.zero) {
      _totalPlayedMs.update(
        song.id,
        (duration) => duration + position.inMilliseconds,
        ifAbsent: () => position.inMilliseconds,
      );
      if (_playbackEvents.isNotEmpty &&
          _playbackEvents.last.songId == song.id) {
        _playbackEvents[_playbackEvents.length - 1] = _playbackEvents.last
            .copyWith(listenedDuration: position);
      }
      _persistEngagements();
      _persistPlaybackEvents();
    }
    _progressTimer?.cancel();
    _dismissUndoTimer?.cancel();
    _sleepTimer?.cancel();
    _sleepTimerTicker?.cancel();
    GoogleCastService.instance.removeListener(_syncGoogleCastState);
    for (final subscription in _playerSubscriptions) {
      unawaited(subscription.cancel());
    }
    final player = _audioPlayer;
    if (player != null) unawaited(player.dispose());
    _persistPlaybackSession();
    positionListenable.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    required AppController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this context.');
    return scope!.notifier!;
  }
}
