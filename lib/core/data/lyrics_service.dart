import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_taglib/flutter_taglib.dart';
import 'package:id3/id3.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_info.dart';
import '../models/lyrics.dart';
import '../models/song.dart';
import 'lyrics_parser.dart';

class LyricsService {
  LyricsService._();

  static final instance = LyricsService._();

  static const _userAgent =
      '${AppInfo.userAgent} '
      '(https://github.com/PixelPlayerHQ/PixelPlayer)';
  static const _amllDbNeteaseLyricsBaseUrl =
      'https://amlldb.bikonoo.com/lyrics/ncm-lyrics/';
  static const _maximumLrcBytes = 256 * 1024;
  static const _maximumTtmlBytes = 1024 * 1024;
  static const _maximumTextCharacters = 50000;
  static const _timingVariantKeywords = <String>{
    'remix',
    'mix',
    'mashup',
    'bootleg',
    'edit',
    'extended',
    'radio',
    'club',
    'vip',
    'dub',
    'live',
    'acoustic',
    'unplugged',
    'sped',
    'slowed',
    'nightcore',
    'instrumental',
    'karaoke',
    'cover',
    'demo',
    'version',
    'rework',
    'flip',
    'refix',
    'opening',
    'ending',
    'op',
    'ed',
    'theme',
    'tv',
    'size',
    'ver',
    'full',
    'movie',
    'ost',
    'soundtrack',
    'background',
    'bgm',
    'short',
    'long',
    'reprise',
    'intro',
    'outro',
    'medley',
    'bonus',
  };
  static const _titleDropQualifiers = <String>{
    'explicit',
    'clean',
    'mono',
    'stereo',
    'official audio',
    'official video',
    'hi res',
    'high res',
    'mqa',
  };
  static const _unknownArtists = <String>{
    '',
    'unknown',
    'unknown artist',
    'various artists',
    'various',
  };
  static const _artistConnectorTokens = <String>{
    'feat',
    'featuring',
    'ft',
    'and',
    'with',
    'x',
    'vs',
    'the',
  };

  static final _bracketedQualifier = RegExp(
    r'[\(\[\{（［｛【『「〔〈《]([^\)\]\}）］｝】』」〕〉》]*)[\)\]\}）］｝】』」〕〉》]',
  );
  static final _featureQualifier = RegExp(
    r'\b(feat(?:uring)?|ft)\.?\b',
    caseSensitive: false,
  );
  static final _titleSeparator = RegExp(r'\s*[-–—:－·・]\s*');

  final Map<String, LyricsDocument> _memoryCache = <String, LyricsDocument>{};
  Future<void> _lrcLibRateLimitTail = Future<void>.value();
  DateTime? _lastLrcLibCall;
  final List<DateTime> _lrcLibCalls = <DateTime>[];

  Future<LyricsDocument?> lyricsFor(
    Song song, {
    LyricsSourcePreference preference = LyricsSourcePreference.embeddedFirst,
    bool includeRemote = true,
    bool forceRefresh = false,
  }) async {
    final isNeteaseTrack = _neteaseSongId(song) != null;
    if (forceRefresh) _memoryCache.remove(song.id);
    if (!forceRefresh) {
      if (!isNeteaseTrack) {
        final cached = _memoryCache[song.id];
        if (cached != null) {
          if (_lyricsTimelineFitsSong(song, cached)) return cached;
          _memoryCache.remove(song.id);
        }
      }
      final stored = await _storedLyrics(song);
      if (stored != null) return _remember(song, stored);
    }

    Future<LyricsDocument?> embedded() => _embeddedLyrics(song);
    Future<LyricsDocument?> local() => _localLyrics(song);
    Future<LyricsDocument?> remote() => fetchBestRemote(song);
    final loaders = switch (preference) {
      LyricsSourcePreference.onlineFirst =>
        includeRemote
            ? <Future<LyricsDocument?> Function()>[remote, embedded, local]
            : <Future<LyricsDocument?> Function()>[embedded, local],
      LyricsSourcePreference.embeddedFirst =>
        includeRemote
            ? <Future<LyricsDocument?> Function()>[embedded, remote, local]
            : <Future<LyricsDocument?> Function()>[embedded, local],
      LyricsSourcePreference.localFirst =>
        includeRemote
            ? <Future<LyricsDocument?> Function()>[local, embedded, remote]
            : <Future<LyricsDocument?> Function()>[local, embedded],
    };

    for (final loader in loaders) {
      try {
        final lyrics = await loader();
        if (lyrics != null && lyrics.hasLyrics) {
          return _remember(song, lyrics);
        }
      } catch (_) {
        // The Kotlin repository moves to the next configured source.
      }
    }
    return null;
  }

  Future<LyricsDocument?> fetchBestRemote(Song song) async {
    final amllLyrics = await _fetchAmlldbLyrics(song);
    if (amllLyrics != null && _lyricsTimelineFitsSong(song, amllLyrics)) {
      await saveLyrics(song, amllLyrics);
      return _remember(song, amllLyrics);
    }
    var results = await _searchRemote(
      song,
      mode: _RemoteLyricsMatchMode.automatic,
    );
    if (results.isEmpty) {
      final exact = await _requestExact(song);
      if (exact != null &&
          _remoteLyricsMatchScore(
                song,
                exact,
                _RemoteLyricsMatchMode.automatic,
              ) !=
              null) {
        results = <LyricsSearchResult>[exact];
      }
    }
    if (results.isEmpty) return null;
    final best = results.first.document;
    await saveLyrics(song, best);
    return _remember(song, best);
  }

  Future<List<LyricsSearchResult>> searchRemote(Song song) =>
      _searchRemote(song, mode: _RemoteLyricsMatchMode.candidate);

  Future<List<LyricsSearchResult>> searchRemoteByQuery(
    Song song, {
    required String title,
    String? artist,
  }) async {
    final cleanTitle = title.trim();
    final cleanArtist = artist?.trim() ?? '';
    if (cleanTitle.isEmpty) return const <LyricsSearchResult>[];
    final query = '$cleanTitle $cleanArtist'.trim();
    final strategies = <Uri>[
      Uri.https('lrclib.net', '/api/search', {'q': query}),
      if (cleanArtist.isNotEmpty)
        Uri.https('lrclib.net', '/api/search', {
          'track_name': cleanTitle,
          'artist_name': cleanArtist,
        }),
    ];
    final results = await _runSearchStrategies(strategies);
    results.sort((a, b) {
      final synced = (b.document.hasSynced ? 1 : 0).compareTo(
        a.document.hasSynced ? 1 : 0,
      );
      return synced != 0 ? synced : a.trackName.compareTo(b.trackName);
    });
    return results;
  }

  String? _neteaseSongId(Song song) {
    final uri = song.contentUri?.trim();
    if (uri != null && uri.isNotEmpty) {
      final parsed = Uri.tryParse(uri);
      if (parsed?.scheme.toLowerCase() == 'netease') {
        final host = parsed?.host.trim() ?? '';
        if (RegExp(r'^\d+$').hasMatch(host)) return host;
        final segments = parsed?.pathSegments ?? const <String>[];
        final path = segments.isEmpty ? '' : segments.first.trim();
        if (RegExp(r'^\d+$').hasMatch(path)) return path;
      }
    }
    if (song.source != SongSource.netease) return null;
    final idMatch = RegExp(r'(\d+)$').firstMatch(song.id);
    return idMatch?.group(1);
  }

  Future<LyricsDocument?> _fetchAmlldbLyrics(Song song) async {
    final neteaseId = _neteaseSongId(song);
    if (neteaseId == null) return null;
    final uri = Uri.parse('$_amllDbNeteaseLyricsBaseUrl$neteaseId');
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      try {
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 18));
        request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
        final body = await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == HttpStatus.notFound) return null;
        if (response.statusCode == HttpStatus.tooManyRequests ||
            response.statusCode >= 500) {
          lastError = HttpException(
            'AMLLDB returned ${response.statusCode}',
            uri: uri,
          );
          if (attempt < 2) {
            await Future<void>.delayed(Duration(milliseconds: 500 << attempt));
            continue;
          }
        }
        if (response.statusCode != HttpStatus.ok) return null;
        if (body.trim().isEmpty ||
            body.contains('\u6b4c\u8bcd\u4e0d\u5b58\u5728')) {
          return null;
        }
        final converted = LyricsParser.ttmlToEnhancedLrc(body);
        if (converted == null) return null;
        final parsed = LyricsParser.parse(converted, fromRemote: true);
        return parsed.hasLyrics ? parsed : null;
      } on SocketException catch (error) {
        lastError = error;
      } on TimeoutException catch (error) {
        lastError = error;
      } finally {
        client.close(force: true);
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 500 << attempt));
      }
    }
    debugPrint('AMLLDB lyrics failed for $neteaseId: $lastError');
    return null;
  }

  Future<List<LyricsSearchResult>> _searchRemote(
    Song song, {
    required _RemoteLyricsMatchMode mode,
  }) async {
    final cleanTitle = song.title.trim();
    final cleanArtist = song.artist.trim();
    if (cleanTitle.isEmpty || song.duration <= Duration.zero) {
      return const <LyricsSearchResult>[];
    }
    final smartTitle = _cleanTitleSmart(cleanTitle);
    final strategies = <Uri>[
      Uri.https('lrclib.net', '/api/search', {
        'q': '$cleanTitle $cleanArtist'.trim(),
      }),
      Uri.https('lrclib.net', '/api/search', {
        'track_name': cleanTitle,
        if (cleanArtist.isNotEmpty) 'artist_name': cleanArtist,
      }),
      if (smartTitle != cleanTitle && smartTitle.isNotEmpty)
        Uri.https('lrclib.net', '/api/search', {'track_name': smartTitle}),
      Uri.https('lrclib.net', '/api/search', {'track_name': cleanTitle}),
      Uri.https('lrclib.net', '/api/search', {'q': cleanTitle}),
    ];

    final results = await _runSearchStrategies(strategies);
    return _rankRemoteResults(song, results, mode);
  }

  List<LyricsSearchResult> _rankRemoteResults(
    Song song,
    List<LyricsSearchResult> results,
    _RemoteLyricsMatchMode mode,
  ) {
    final matches = <({LyricsSearchResult result, int score})>[];
    for (final result in results) {
      final score = _remoteLyricsMatchScore(song, result, mode);
      if (score != null) matches.add((result: result, score: score));
    }
    matches.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      final synced = (b.result.document.hasSynced ? 1 : 0).compareTo(
        a.result.document.hasSynced ? 1 : 0,
      );
      if (synced != 0) return synced;
      final aDiff = (a.result.duration - song.duration).abs();
      final bDiff = (b.result.duration - song.duration).abs();
      return aDiff.compareTo(bDiff);
    });
    return matches.map((match) => match.result).toList(growable: false);
  }

  @visibleForTesting
  List<LyricsSearchResult> rankRemoteResultsForTesting(
    Song song,
    List<LyricsSearchResult> results, {
    bool automatic = true,
  }) {
    return _rankRemoteResults(
      song,
      results,
      automatic
          ? _RemoteLyricsMatchMode.automatic
          : _RemoteLyricsMatchMode.candidate,
    );
  }

  Future<void> saveLyrics(Song song, LyricsDocument document) async {
    if (!document.hasLyrics ||
        document.raw.trim().isEmpty ||
        !_lyricsTimelineFitsSong(song, document)) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey(song.id), document.raw.trim());
    _memoryCache[song.id] = LyricsParser.parse(document.raw);
  }

  Future<LyricsDocument> importLyricsFile(Song song, File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    if (extension != 'lrc' && extension != 'ttml') {
      throw const FormatException(
        'Only .lrc and .ttml lyrics files are supported.',
      );
    }
    if (!await file.exists()) {
      throw const FormatException('Lyrics file is empty.');
    }
    final maximumBytes = extension == 'ttml'
        ? _maximumTtmlBytes
        : _maximumLrcBytes;
    if (await file.length() > maximumBytes) {
      throw const FormatException('Lyrics file is too large.');
    }
    final bytes = await file.readAsBytes();
    final decoded = _decodeText(bytes);
    if (decoded == null) {
      throw const FormatException('Lyrics file could not be decoded safely.');
    }
    final raw = extension == 'ttml'
        ? LyricsParser.ttmlToEnhancedLrc(decoded)
        : LyricsParser.sanitizeImported(decoded);
    if (raw == null || raw.isEmpty || raw.length > _maximumTextCharacters) {
      throw const FormatException('File does not contain valid lyrics.');
    }
    final document = LyricsParser.parse(raw);
    if (!document.hasSynced) {
      throw const FormatException('File does not contain valid lyrics.');
    }
    await saveLyrics(song, document);
    return document;
  }

  Future<void> resetLyrics(Song song) async {
    _memoryCache.remove(song.id);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey(song.id));
  }

  Future<void> resetAllLyrics() async {
    _memoryCache.clear();
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences
        .getKeys()
        .where((key) => key.startsWith('lyrics_content_'))
        .toList(growable: false);
    for (final key in keys) {
      await preferences.remove(key);
    }
  }

  Future<int> scanAndAssignLocalFiles(
    List<Song> songs, {
    void Function(int current, int total)? onProgress,
  }) async {
    final localSongs = songs
        .where((song) => song.source == SongSource.local && song.path != null)
        .toList(growable: false);
    final total = localSongs.length;
    if (total == 0) {
      onProgress?.call(0, 0);
      return 0;
    }
    final preferences = await SharedPreferences.getInstance();
    var cursor = 0;
    var processed = 0;
    var updated = 0;

    Future<void> worker() async {
      while (true) {
        final index = cursor++;
        if (index >= total) return;
        final song = localSongs[index];
        try {
          final key = _storageKey(song.id);
          if (!(preferences.getString(key)?.trim().isNotEmpty ?? false)) {
            final lyrics = await _localLyrics(song);
            if (lyrics != null && lyrics.hasLyrics) {
              await preferences.setString(key, lyrics.raw.trim());
              _memoryCache[song.id] = lyrics;
              updated++;
            }
          }
        } catch (_) {
          // A damaged/unavailable file must not stop the rest of the scan.
        } finally {
          processed++;
          if (processed % 20 == 0 || processed == total) {
            onProgress?.call(processed, total);
          }
        }
      }
    }

    await Future.wait(
      List<Future<void>>.generate(math.min(8, total), (_) => worker()),
    );
    return updated;
  }

  Future<LyricsDocument?> _storedLyrics(Song song) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _storageKey(song.id);
    final raw = preferences.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = LyricsParser.parse(raw);
    if (!parsed.hasLyrics || !_lyricsTimelineFitsSong(song, parsed)) {
      await preferences.remove(key);
      _memoryCache.remove(song.id);
      return null;
    }
    return parsed;
  }

  Future<LyricsDocument?> _embeddedLyrics(Song song) async {
    final path = song.path;
    if (path == null || song.source == SongSource.telegram) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final properties = await Isolate.run(() => _readTagLibProperties(path));
      final tagLibLyrics = _bestEmbeddedLyrics(properties);
      if (tagLibLyrics != null) return tagLibLyrics;
      if (!path.toLowerCase().endsWith('.mp3')) return null;
      final parser = MP3Instance(await file.readAsBytes());
      if (!parser.parseTagsSync()) return null;
      final tags = parser.getMetaTags();
      final uslt = tags?['USLT'];
      final raw = uslt is Map ? uslt['lyrics']?.toString() : uslt?.toString();
      if (raw == null || raw.trim().isEmpty) return null;
      final parsed = LyricsParser.parse(raw);
      return parsed.hasLyrics ? parsed : null;
    } catch (_) {
      return null;
    }
  }

  LyricsDocument? _bestEmbeddedLyrics(Map<String, List<String>>? properties) {
    LyricsDocument? firstPlainLyrics;
    for (final key in const <String>[
      'LYRICS',
      'SYNCEDLYRICS',
      'TTML',
      'UNSYNCEDLYRICS',
    ]) {
      for (final field in properties?[key] ?? const <String>[]) {
        if (field.trim().isEmpty) continue;
        final parsed = LyricsParser.parse(field);
        if (!parsed.hasLyrics) continue;
        if (parsed.hasSynced) return parsed;
        firstPlainLyrics ??= parsed;
      }
    }
    return firstPlainLyrics;
  }

  @visibleForTesting
  LyricsDocument? bestEmbeddedLyricsForTesting(
    Map<String, List<String>> properties,
  ) => _bestEmbeddedLyrics(properties);

  Future<LyricsDocument?> _localLyrics(Song song) async {
    final path = song.path;
    if (path == null) return null;
    final audioFile = File(path);
    final directory = audioFile.parent;
    final dot = audioFile.path.lastIndexOf('.');
    final basePath = dot < 0
        ? audioFile.path
        : audioFile.path.substring(0, dot);
    final safeArtist = song.artist.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final safeTitle = song.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    for (final extension in const <String>['lrc', 'ttml']) {
      final candidates = <File>[
        File('$basePath.$extension'),
        File(
          '${directory.path}${Platform.pathSeparator}'
          '${safeArtist}_$safeTitle.$extension',
        ),
      ];
      for (final file in candidates) {
        try {
          if (!await file.exists()) continue;
          return await _readLocalFile(file, extension);
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  Future<LyricsDocument?> _readLocalFile(File file, String extension) async {
    final maximumBytes = extension == 'ttml'
        ? _maximumTtmlBytes
        : _maximumLrcBytes;
    if (await file.length() > maximumBytes) return null;
    final text = _decodeText(await file.readAsBytes());
    if (text == null) return null;
    final raw = extension == 'ttml'
        ? LyricsParser.ttmlToEnhancedLrc(text)
        : LyricsParser.sanitizeImported(text);
    if (raw == null || raw.length > _maximumTextCharacters) return null;
    final parsed = LyricsParser.parse(raw);
    return parsed.hasLyrics ? parsed : null;
  }

  Future<List<LyricsSearchResult>> _requestSearch(Uri uri) async {
    final body = await _getLrcLib(uri);
    if (body == null) return const <LyricsSearchResult>[];
    final decoded = jsonDecode(body);
    if (decoded is! List) return const <LyricsSearchResult>[];
    return decoded
        .whereType<Map>()
        .map((item) => _resultFromJson(Map<String, dynamic>.from(item)))
        .whereType<LyricsSearchResult>()
        .toList(growable: false);
  }

  Future<List<LyricsSearchResult>> _runSearchStrategies(
    List<Uri> strategies,
  ) async {
    final batches = await Future.wait(
      strategies.map((uri) async {
        try {
          return await _requestSearch(uri);
        } catch (_) {
          return const <LyricsSearchResult>[];
        }
      }),
    );
    final unique = <int, LyricsSearchResult>{};
    for (final batch in batches) {
      for (final result in batch) {
        unique.putIfAbsent(result.id, () => result);
      }
    }
    return unique.values.toList();
  }

  Future<LyricsSearchResult?> _requestExact(Song song) async {
    final uri = Uri.https('lrclib.net', '/api/get', {
      'track_name': song.title,
      'artist_name': song.artist,
      'album_name': song.album,
      'duration': song.duration.inSeconds.toString(),
    });
    final body = await _getLrcLib(uri);
    if (body == null) return null;
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    return _resultFromJson(Map<String, dynamic>.from(decoded));
  }

  Future<String?> _getLrcLib(Uri uri) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      await _waitForLrcLibSlot();
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      try {
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 18));
        request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
        final body = await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == HttpStatus.notFound) return null;
        if (response.statusCode == HttpStatus.tooManyRequests ||
            response.statusCode >= 500) {
          lastError = HttpException(
            'Lyrics service returned ${response.statusCode}',
            uri: uri,
          );
          if (attempt < 2) {
            await Future<void>.delayed(Duration(milliseconds: 500 << attempt));
            continue;
          }
        }
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Lyrics service returned ${response.statusCode}',
            uri: uri,
          );
        }
        return body;
      } on SocketException catch (error) {
        lastError = error;
      } on TimeoutException catch (error) {
        lastError = error;
      } finally {
        client.close(force: true);
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 500 << attempt));
      }
    }
    throw lastError ?? HttpException('Lyrics request failed', uri: uri);
  }

  Future<void> _waitForLrcLibSlot() {
    final previous = _lrcLibRateLimitTail;
    final completer = Completer<void>();
    _lrcLibRateLimitTail = completer.future;
    return () async {
      await previous;
      try {
        final now = DateTime.now();
        _lrcLibCalls.removeWhere(
          (call) => now.difference(call) >= const Duration(minutes: 1),
        );
        var wait = Duration.zero;
        final lastCall = _lastLrcLibCall;
        if (lastCall != null) {
          final sinceLast = now.difference(lastCall);
          if (sinceLast < const Duration(milliseconds: 100)) {
            wait = const Duration(milliseconds: 100) - sinceLast;
          }
        }
        if (_lrcLibCalls.length >= 30) {
          final untilWindowOpens =
              const Duration(minutes: 1) - now.difference(_lrcLibCalls.first);
          if (untilWindowOpens > wait) wait = untilWindowOpens;
        }
        if (wait > Duration.zero) await Future<void>.delayed(wait);
        final calledAt = DateTime.now();
        _lastLrcLibCall = calledAt;
        _lrcLibCalls.add(calledAt);
      } finally {
        completer.complete();
      }
    }();
  }

  LyricsSearchResult? _resultFromJson(Map<String, dynamic> json) {
    if (json['instrumental'] == true) return null;
    final raw = (json['syncedLyrics'] ?? json['plainLyrics'])?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = LyricsParser.parse(raw, fromRemote: true);
    if (!parsed.hasLyrics) return null;
    final durationSeconds = switch (json['duration']) {
      final num value => value.round(),
      _ => 0,
    };
    return LyricsSearchResult(
      id: switch (json['id']) {
        final num value => value.toInt(),
        _ => raw.hashCode,
      },
      trackName:
          json['trackName']?.toString() ??
          json['name']?.toString() ??
          'Unknown title',
      artistName: json['artistName']?.toString() ?? 'Unknown artist',
      albumName: json['albumName']?.toString() ?? '',
      duration: Duration(seconds: durationSeconds),
      document: parsed,
    );
  }

  int? _remoteLyricsMatchScore(
    Song song,
    LyricsSearchResult result,
    _RemoteLyricsMatchMode mode,
  ) {
    if (!result.document.hasLyrics || result.duration <= Duration.zero) {
      return null;
    }
    if (!_lyricsTimelineFitsSong(song, result.document)) return null;
    if (!_variantDescriptorsCompatible(song, result)) return null;

    final durationSeconds = song.duration.inMilliseconds / 1000;
    final resultSeconds = result.duration.inMilliseconds / 1000;
    final tolerance = switch (mode) {
      _RemoteLyricsMatchMode.automatic when result.document.hasSynced =>
        (durationSeconds * .02).clamp(5.0, 8.0),
      _RemoteLyricsMatchMode.automatic => (durationSeconds * .04).clamp(
        8.0,
        15.0,
      ),
      _RemoteLyricsMatchMode.candidate => 15.0,
    };
    final durationDifference = (resultSeconds - durationSeconds).abs();
    if (durationDifference > tolerance) return null;

    final titleScore = _titleMatchScore(song.title, result.trackName, mode);
    if (titleScore == null) return null;
    final artistScore = _artistMatchScore(song.artist, result.artistName);
    if (!_isUnknownArtist(song.artist) && artistScore == null) return null;

    return titleScore +
        (artistScore ?? 0) +
        math.max(0, tolerance - durationDifference).toInt() +
        (result.document.hasSynced ? 10 : 0);
  }

  bool _lyricsTimelineFitsSong(Song song, LyricsDocument lyrics) {
    if (!lyrics.hasSynced || song.duration <= Duration.zero) return true;
    final durationMs = song.duration.inMilliseconds;
    final toleranceMs = (durationMs * .05).round().clamp(8000, 30000);
    return lyrics.synced.last.time.inMilliseconds <= durationMs + toleranceMs;
  }

  int? _titleMatchScore(
    String songTitle,
    String responseTitle,
    _RemoteLyricsMatchMode mode,
  ) {
    final songBase = _baseTitleForMatching(songTitle);
    final responseBase = _baseTitleForMatching(responseTitle);
    if (songBase.isEmpty || responseBase.isEmpty) return null;
    if (songBase == responseBase) return 70;

    final songTokens = _tokens(songBase);
    final responseTokens = _tokens(responseBase);
    if (songTokens.isEmpty || responseTokens.isEmpty) return null;
    if (songTokens.length == 1 || responseTokens.length == 1) {
      if (songTokens.length == responseTokens.length &&
          songTokens.first == responseTokens.first) {
        return 60;
      }
      final first = songBase.replaceAll(' ', '');
      final second = responseBase.replaceAll(' ', '');
      if (first.isNotEmpty &&
          second.isNotEmpty &&
          (first.contains(second) || second.contains(first))) {
        return 55;
      }
      return null;
    }
    if (_containsWholePhrase(responseBase, songBase) ||
        _containsWholePhrase(songBase, responseBase)) {
      return mode == _RemoteLyricsMatchMode.automatic ? 58 : 54;
    }
    final overlap = songTokens.intersection(responseTokens).length;
    final songCoverage = overlap / songTokens.length;
    final responseCoverage = overlap / responseTokens.length;
    final requiredSong = mode == _RemoteLyricsMatchMode.automatic ? .85 : .75;
    final requiredResponse = mode == _RemoteLyricsMatchMode.automatic
        ? .70
        : .55;
    return songCoverage >= requiredSong && responseCoverage >= requiredResponse
        ? 45
        : null;
  }

  int? _artistMatchScore(String songArtist, String responseArtist) {
    if (_isUnknownArtist(songArtist)) return 0;
    final songBase = _normalize(songArtist);
    final responseBase = _normalize(responseArtist);
    if (songBase.isEmpty || responseBase.isEmpty) return null;
    if (songBase == responseBase) return 30;
    if (_containsWholePhrase(responseBase, songBase) ||
        _containsWholePhrase(songBase, responseBase)) {
      return 22;
    }
    final songTokens = _tokens(songBase).difference(_artistConnectorTokens);
    final responseTokens = _tokens(
      responseBase,
    ).difference(_artistConnectorTokens);
    if (songTokens.isEmpty || responseTokens.isEmpty) return null;
    final overlap = songTokens.intersection(responseTokens).length;
    final coverage =
        overlap / math.min(songTokens.length, responseTokens.length);
    return coverage >= .5 ? 12 : null;
  }

  bool _variantDescriptorsCompatible(Song song, LyricsSearchResult result) {
    final songVariants = <String>{
      ..._timingVariantTokens(song.title),
      ..._timingVariantTokensFromFileName(song),
    };
    final responseVariants = _timingVariantTokens(result.trackName);
    if (songVariants.isEmpty) return responseVariants.isEmpty;
    return songVariants.length == responseVariants.length &&
        songVariants.containsAll(responseVariants);
  }

  String _baseTitleForMatching(String title) {
    var base = title.replaceFirst(RegExp(r'^\s*\d{1,3}\s*[\._-]\s+'), '');
    base = base.replaceAllMapped(_bracketedQualifier, (match) {
      final qualifier = match.group(1) ?? '';
      return _shouldDropTitleQualifier(qualifier) ? ' ' : ' $qualifier ';
    });
    var parts = base.split(_titleSeparator);
    while (parts.length > 1 && _shouldDropTitleQualifier(parts.last)) {
      parts = parts.sublist(0, parts.length - 1);
    }
    return _normalize(parts.join(' '));
  }

  bool _shouldDropTitleQualifier(String value) {
    final normalized = _normalize(value);
    return normalized.isEmpty ||
        _featureQualifier.hasMatch(value) ||
        _timingVariantTokens(value).isNotEmpty ||
        _titleDropQualifiers.contains(normalized);
  }

  Set<String> _timingVariantTokens(String value) {
    final normalized = _normalize(value);
    final tokens = _tokens(normalized);
    final variants = tokens.where(_timingVariantKeywords.contains).toSet();
    if (RegExp(r'\bmash\s+up\b').hasMatch(normalized)) {
      variants.add('mashup');
    }
    if (tokens.contains('versus') || tokens.contains('vs')) {
      variants.add('mashup');
    }
    return variants;
  }

  Set<String> _timingVariantTokensFromFileName(Song song) {
    final path = song.path;
    if (path == null || path.isEmpty) return const <String>{};
    final fileName = path
        .split(RegExp(r'[/\\]'))
        .last
        .replaceFirst(RegExp(r'\.[^.]+$'), '');
    final variants = <String>{};
    for (final match in _bracketedQualifier.allMatches(fileName)) {
      variants.addAll(_timingVariantTokens(match.group(1) ?? ''));
    }
    final titleBase = _baseTitleForMatching(song.title);
    if (titleBase.isEmpty) return variants;
    for (final part in fileName.split(_titleSeparator)) {
      final normalized = _normalize(part);
      if (normalized.startsWith('$titleBase ')) {
        variants.addAll(
          _timingVariantTokens(normalized.substring(titleBase.length).trim()),
        );
      }
    }
    return variants;
  }

  Set<String> _tokens(String value) =>
      value.split(' ').where((token) => token.isNotEmpty).toSet();

  bool _containsWholePhrase(String haystack, String needle) {
    if (needle.isEmpty) return false;
    return RegExp(
      r'(?:^|\s)' + RegExp.escape(needle) + r'(?:\s|$)',
    ).hasMatch(haystack);
  }

  bool _isUnknownArtist(String value) =>
      _unknownArtists.contains(_normalize(value));

  String _cleanTitleSmart(String value) => value
      .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ')
      .replaceAll(
        RegExp(r'\b(feat(?:uring)?|ft)\.?\s+.*$', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r"[’'`]"), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String? _decodeText(List<int> bytes) {
    if (bytes.length >= 2 &&
        ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
            (bytes[0] == 0xfe && bytes[1] == 0xff))) {
      final littleEndian = bytes[0] == 0xff;
      final codeUnits = <int>[];
      for (var index = 2; index + 1 < bytes.length; index += 2) {
        codeUnits.add(
          littleEndian
              ? bytes[index] | (bytes[index + 1] << 8)
              : (bytes[index] << 8) | bytes[index + 1],
        );
      }
      return String.fromCharCodes(codeUnits);
    }
    try {
      var offset = 0;
      if (bytes.length >= 3 &&
          bytes[0] == 0xef &&
          bytes[1] == 0xbb &&
          bytes[2] == 0xbf) {
        offset = 3;
      }
      return utf8.decode(bytes.sublist(offset), allowMalformed: false);
    } on FormatException {
      return null;
    }
  }

  LyricsDocument _remember(Song song, LyricsDocument document) {
    _memoryCache[song.id] = document;
    return document;
  }

  String _storageKey(String songId) => 'lyrics_content_$songId';
}

enum _RemoteLyricsMatchMode { automatic, candidate }

Map<String, List<String>>? _readTagLibProperties(String path) {
  if (!TagLibFile.isSupported) return null;
  final file = TagLibFile.open(path);
  if (file == null) return null;
  try {
    return file.properties;
  } finally {
    file.close();
  }
}
