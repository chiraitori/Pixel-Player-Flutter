import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../models/song.dart';

class GoogleCastService extends ChangeNotifier {
  GoogleCastService._();

  static final instance = GoogleCastService._();

  final _mediaServer = _CastMediaServer();
  StreamSubscription<GoogleCastSession?>? _sessionSubscription;
  StreamSubscription<GoggleCastMediaStatus?>? _mediaStatusSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  bool _initialized = false;
  bool _initializing = false;
  bool connecting = false;
  String? routeName;
  String? lastError;
  Duration remotePosition = Duration.zero;
  bool remoteIsPlaying = false;

  bool get initialized => _initialized;
  bool get connected =>
      _initialized && GoogleCastSessionManager.instance.hasConnectedSession;
  Stream<List<GoogleCastDevice>> get devicesStream =>
      GoogleCastDiscoveryManager.instance.devicesStream;

  Future<void> initialize() async {
    if (_initialized ||
        _initializing ||
        (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    _initializing = true;
    try {
      const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
      final options = Platform.isAndroid
          ? GoogleCastOptionsAndroid(appId: appId)
          : IOSGoogleCastOptions(
              GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(
                appId,
              ),
            );
      await GoogleCastContext.instance.setSharedInstanceWithOptions(options);
      _sessionSubscription ??= GoogleCastSessionManager
          .instance
          .currentSessionStream
          .listen((session) {
            routeName = session?.device?.friendlyName;
            connecting = false;
            if (session == null) remoteIsPlaying = false;
            notifyListeners();
          });
      _mediaStatusSubscription ??= GoogleCastRemoteMediaClient
          .instance
          .mediaStatusStream
          .listen((status) {
            remoteIsPlaying =
                status?.playerState == CastMediaPlayerState.playing ||
                status?.playerState == CastMediaPlayerState.buffering ||
                status?.playerState == CastMediaPlayerState.loading;
            notifyListeners();
          });
      _positionSubscription ??= GoogleCastRemoteMediaClient
          .instance
          .playerPositionStream
          .listen((position) {
            remotePosition = position;
            notifyListeners();
          });
      _initialized = true;
    } on Object catch (error) {
      lastError = 'Could not initialize Google Cast: $error';
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> startDiscovery() async {
    await initialize();
    if (!_initialized) return;
    await GoogleCastDiscoveryManager.instance.startDiscovery();
  }

  Future<void> stopDiscovery() async {
    if (!_initialized) return;
    await GoogleCastDiscoveryManager.instance.stopDiscovery();
  }

  Future<void> castSong(
    GoogleCastDevice device,
    Song song, {
    Duration position = Duration.zero,
  }) async {
    await initialize();
    if (!_initialized) {
      throw StateError(lastError ?? 'Google Cast is unavailable.');
    }
    connecting = true;
    lastError = null;
    notifyListeners();
    try {
      final started = await GoogleCastSessionManager.instance
          .startSessionWithDevice(device);
      if (!started && !GoogleCastSessionManager.instance.hasConnectedSession) {
        throw StateError('Could not start a Cast session.');
      }
      await _waitForConnectedSession();
      await loadSong(song, position: position);
      routeName = device.friendlyName;
    } on Object catch (error) {
      lastError = 'Could not cast this song: $error';
      rethrow;
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  Future<void> loadSong(Song song, {Duration position = Duration.zero}) async {
    if (!connected) return;
    final mediaUrl = await _mediaServer.urlFor(song);
    final mediaInfo = Platform.isIOS
        ? GoogleCastMediaInformationIOS(
            contentId: song.id,
            contentUrl: mediaUrl,
            streamType: CastMediaStreamType.buffered,
            contentType: song.mimeType ?? 'audio/mpeg',
            duration: song.duration > Duration.zero ? song.duration : null,
            metadata: GoogleCastMusicMediaMetadata(
              title: song.title,
              artist: song.artist,
              albumName: song.album,
              discNumber: song.disc,
              trackNumber: song.track,
            ),
          )
        : GoogleCastMediaInformationAndroid(
            contentId: song.id,
            contentUrl: mediaUrl,
            streamType: CastMediaStreamType.buffered,
            contentType: song.mimeType ?? 'audio/mpeg',
            duration: song.duration > Duration.zero ? song.duration : null,
            metadata: GoogleCastMusicMediaMetadataAndroid(
              title: song.title,
              artist: song.artist,
              albumName: song.album,
              discNumber: song.disc,
              trackNumber: song.track,
            ),
          );
    await GoogleCastRemoteMediaClient.instance.loadMedia(
      mediaInfo,
      autoPlay: true,
      playPosition: position,
    );
    remotePosition = position;
    remoteIsPlaying = true;
    notifyListeners();
  }

  Future<void> play() async {
    if (connected) await GoogleCastRemoteMediaClient.instance.play();
  }

  Future<void> pause() async {
    if (connected) await GoogleCastRemoteMediaClient.instance.pause();
  }

  Future<void> seek(Duration position) async {
    if (!connected) return;
    await GoogleCastRemoteMediaClient.instance.seek(
      GoogleCastMediaSeekOption(position: position),
    );
    remotePosition = position;
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (!_initialized) return;
    await GoogleCastSessionManager.instance.endSessionAndStopCasting();
    routeName = null;
    remoteIsPlaying = false;
    await _mediaServer.stop();
    notifyListeners();
  }

  Future<void> _waitForConnectedSession() async {
    if (GoogleCastSessionManager.instance.hasConnectedSession) return;
    await GoogleCastSessionManager.instance.currentSessionStream
        .firstWhere((session) => session != null)
        .timeout(const Duration(seconds: 12));
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _mediaStatusSubscription?.cancel();
    _positionSubscription?.cancel();
    _mediaServer.stop();
    super.dispose();
  }
}

class _CastMediaServer {
  HttpServer? _server;
  Song? _song;
  late String _token;

  Future<Uri> urlFor(Song song) async {
    _song = song;
    _token = base64UrlEncode(
      List<int>.generate(24, (_) => Random.secure().nextInt(256)),
    ).replaceAll('=', '');
    if (_server == null) {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _server!.listen(_handleRequest);
    }
    final address = await _localIpv4Address();
    return Uri(
      scheme: 'http',
      host: address,
      port: _server!.port,
      pathSegments: [_token, 'media'],
    );
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _song = null;
    if (server != null) await server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final song = _song;
    if (song == null ||
        request.uri.pathSegments.length != 2 ||
        request.uri.pathSegments.first != _token ||
        request.uri.pathSegments.last != 'media') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    request.response.headers
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.contentTypeHeader, song.mimeType ?? 'audio/mpeg');
    try {
      final path = song.path;
      if (path != null && await File(path).exists()) {
        await _serveFile(request, File(path));
      } else if (song.playbackUri?.isScheme('http') == true ||
          song.playbackUri?.isScheme('https') == true) {
        await _proxyRemote(request, song);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } on Object {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
      } on StateError {
        // The response may already be streaming to the Cast receiver.
      }
      try {
        await request.response.close();
      } on StateError {
        // Nothing else can be written once the response is closed.
      }
    }
  }

  Future<void> _serveFile(HttpRequest request, File file) async {
    final length = await file.length();
    final range = _parseRange(
      request.headers.value(HttpHeaders.rangeHeader),
      length,
    );
    if (range == null) {
      request.response.statusCode = HttpStatus.ok;
      request.response.contentLength = length;
      if (request.method != 'HEAD') {
        await request.response.addStream(file.openRead());
      }
    } else {
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes ${range.start}-${range.end}/$length',
      );
      request.response.contentLength = range.end - range.start + 1;
      if (request.method != 'HEAD') {
        await request.response.addStream(
          file.openRead(range.start, range.end + 1),
        );
      }
    }
    await request.response.close();
  }

  Future<void> _proxyRemote(HttpRequest request, Song song) async {
    final client = HttpClient();
    try {
      final outgoing = await client.getUrl(song.playbackUri!);
      for (final header in song.playbackHeaders.entries) {
        outgoing.headers.set(header.key, header.value);
      }
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) outgoing.headers.set(HttpHeaders.rangeHeader, range);
      final incoming = await outgoing.close();
      request.response.statusCode = incoming.statusCode;
      for (final name in const [
        HttpHeaders.contentLengthHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
        HttpHeaders.contentTypeHeader,
      ]) {
        final value = incoming.headers.value(name);
        if (value != null) request.response.headers.set(name, value);
      }
      if (request.method != 'HEAD') {
        await request.response.addStream(incoming);
      }
      await request.response.close();
    } finally {
      client.close(force: true);
    }
  }

  _ByteRange? _parseRange(String? value, int length) {
    if (value == null || !value.startsWith('bytes=')) return null;
    final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(value);
    if (match == null) return null;
    final start = int.tryParse(match.group(1)!);
    final requestedEnd = int.tryParse(match.group(2) ?? '');
    if (start == null || start < 0 || start >= length) return null;
    return _ByteRange(start, min(requestedEnd ?? length - 1, length - 1));
  }

  Future<String> _localIpv4Address() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final addresses = interfaces
        .expand((interface) => interface.addresses)
        .where((address) => !address.isLoopback)
        .toList(growable: false);
    if (addresses.isEmpty) {
      throw const SocketException('No local Wi-Fi address is available.');
    }
    return addresses
        .firstWhere(
          (address) =>
              address.address.startsWith('192.168.') ||
              address.address.startsWith('10.') ||
              address.address.startsWith('172.'),
          orElse: () => addresses.first,
        )
        .address;
  }
}

class _ByteRange {
  const _ByteRange(this.start, this.end);

  final int start;
  final int end;
}
