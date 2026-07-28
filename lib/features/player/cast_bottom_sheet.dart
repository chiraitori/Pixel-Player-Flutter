import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/entities.dart' show GoogleCastDevice;
import 'package:permission_handler/permission_handler.dart';

import '../../core/models/song.dart';
import '../../core/services/google_cast_service.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/pixelplay_theme.dart';
import '../../core/theme/player_palette_cache.dart';
import 'player_color_scheme_transition.dart';

Future<void> showCastBottomSheet({
  required BuildContext context,
  required Song? song,
  ValueChanged<bool>? onVisibilityChanged,
}) async {
  final cast = GoogleCastService.instance;
  await cast.startDiscovery();
  if (!context.mounted) return;

  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  onVisibilityChanged?.call(true);
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      sheetAnimationStyle: reduceMotion
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 220),
              reverseDuration: Duration(milliseconds: 180),
            ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CastBottomSheetContent(song: song),
    );
  } finally {
    onVisibilityChanged?.call(false);
    await cast.stopDiscovery();
  }
}

class _CastBottomSheetContent extends StatefulWidget {
  const _CastBottomSheetContent({required this.song});

  final Song? song;

  @override
  State<_CastBottomSheetContent> createState() =>
      __CastBottomSheetContentState();
}

class __CastBottomSheetContentState extends State<_CastBottomSheetContent>
    with WidgetsBindingObserver {
  static const _deviceChannel = MethodChannel(
    'com.chiraitori.pixelplay/device_capabilities',
  );
  static const _bluetoothDevicesChannel = EventChannel(
    'com.chiraitori.pixelplay/bluetooth_audio_devices',
  );

  late int _selectedTab; // 0 = CONTROLS, 1 = DEVICES
  late final PageController _pageController;

  bool _isWifiOn = false;
  bool _isWifiConnected = false;
  String? _wifiSsid;
  bool _isBluetoothEnabled = false;
  bool _isBluetoothActive = false;
  String? _bluetoothName;
  int _mediaVolumeLevel = 1;
  int _mediaVolumeMax = 1;
  int _lastVolumeStep = -1;
  bool _isScanning = true;
  int _castDeviceCount = 0;
  List<_BluetoothAudioDevice> _bluetoothDevices = const [];
  StreamSubscription<dynamic>? _bluetoothDevicesSubscription;
  Timer? _scanTimer;
  String? _paletteSongId;
  Color? _artworkSeed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cast = GoogleCastService.instance;
    _selectedTab = cast.connected || cast.connecting ? 0 : 1;
    _pageController = PageController(initialPage: _selectedTab);
    unawaited(_initializeBluetoothOutputs());
    _scheduleScanEnd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanTimer?.cancel();
    unawaited(_bluetoothDevicesSubscription?.cancel());
    if (Platform.isAndroid || Platform.isIOS) {
      unawaited(_deviceChannel.invokeMethod<void>('stopBluetoothDiscovery'));
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadCapabilities());
      unawaited(_refreshBluetoothOutputs());
    }
  }

  Future<int?> _loadCapabilities() async {
    try {
      final map = await _deviceChannel.invokeMethod<Map>('getCapabilities');
      if (map != null && mounted) {
        setState(() {
          final maxVolume = (map['mediaVolumeMax'] as num?)?.toInt() ?? 1;
          _mediaVolumeMax = maxVolume > 0 ? maxVolume : 1;
          _mediaVolumeLevel =
              ((map['mediaVolume'] as num?)?.toInt() ?? _mediaVolumeLevel)
                  .clamp(0, _mediaVolumeMax);
          _lastVolumeStep = _mediaVolumeLevel;
          _isWifiOn = map['wifiOn'] == true;
          _isWifiConnected = map['wifiConnected'] == true;
          _wifiSsid = map['wifiSsid']?.toString();
          _isBluetoothEnabled = map['bluetoothEnabled'] == true;
          _isBluetoothActive = map['bluetoothActive'] == true;
          _bluetoothName = map['bluetoothName']?.toString();
        });
      }
      return (map?['sdk'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<void> _initializeBluetoothOutputs() async {
    final sdk = await _loadCapabilities();
    if ((!Platform.isAndroid && !Platform.isIOS) || !mounted) return;

    if (Platform.isAndroid) {
      if (sdk == null) return;
      final permissions = sdk >= 31
          ? [Permission.bluetoothScan, Permission.bluetoothConnect]
          : [Permission.locationWhenInUse];
      final statuses = await permissions.request();
      if (!mounted || statuses.values.any((status) => !status.isGranted)) {
        return;
      }
    }

    _bluetoothDevicesSubscription ??= _bluetoothDevicesChannel
        .receiveBroadcastStream()
        .listen(_applyBluetoothDevices, onError: (_) {});
    await _refreshBluetoothOutputs();
  }

  Future<void> _refreshBluetoothOutputs() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await _deviceChannel.invokeMethod<bool>('startBluetoothDiscovery');
      final devices = await _deviceChannel.invokeListMethod<dynamic>(
        'getBluetoothAudioDevices',
      );
      if (devices != null) _applyBluetoothDevices(devices);
    } on PlatformException {
      // Keep Google Cast discovery working if Bluetooth is unavailable.
    }
  }

  void _applyBluetoothDevices(dynamic event) {
    if (!mounted || event is! List) return;
    final devices = event
        .whereType<Map>()
        .map(_BluetoothAudioDevice.fromMap)
        .where((device) => device.name.isNotEmpty)
        .toList(growable: false);
    setState(() {
      _bluetoothDevices = devices;
      _isBluetoothActive = devices.any((device) => device.isConnected);
      _bluetoothName = devices
          .where((device) => device.isConnected)
          .map((device) => device.name)
          .firstOrNull;
    });
  }

  Future<void> _setPhoneMediaVolume(int requestedLevel) async {
    final level = requestedLevel.clamp(0, _mediaVolumeMax);
    try {
      final result = await _deviceChannel.invokeMapMethod<String, dynamic>(
        'setMediaVolume',
        {'level': level},
      );
      if (!mounted || level != _mediaVolumeLevel || result == null) return;
      setState(() {
        final maxVolume = (result['mediaVolumeMax'] as num?)?.toInt() ?? 1;
        _mediaVolumeMax = maxVolume > 0 ? maxVolume : 1;
        _mediaVolumeLevel = ((result['mediaVolume'] as num?)?.toInt() ?? level)
            .clamp(0, _mediaVolumeMax);
      });
    } catch (_) {}
  }

  void _scheduleScanEnd() {
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted && _isScanning) setState(() => _isScanning = false);
    });
  }

  void _startDiscovery() {
    if (!_isScanning) setState(() => _isScanning = true);
    _scheduleScanEnd();
    unawaited(GoogleCastService.instance.startDiscovery());
    unawaited(_refreshBluetoothOutputs());
  }

  void _onTabSelected(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _syncArtworkSeed(Song song) {
    if (_paletteSongId == song.id) return;
    _paletteSongId = song.id;
    _artworkSeed = song.colors.isEmpty ? Colors.deepPurple : song.colors.first;
    final requestedSongId = song.id;
    unawaited(() async {
      final seed = await PlayerPaletteCache.seedFor(song);
      if (!mounted || _paletteSongId != requestedSongId) return;
      setState(() => _artworkSeed = seed);
    }());
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final song = controller.currentSong ?? widget.song;
    if (song != null) _syncArtworkSeed(song);

    final baseTheme = Theme.of(context);
    final useAlbumColors =
        song != null &&
        controller.stringSetting(
              'appearance_player_palette',
              controller.boolSetting('appearance_use_album_colors', true)
                  ? 'Album Art'
                  : 'System Dynamic',
            ) ==
            'Album Art';
    final variant = switch (controller.stringSetting(
      'appearance_palette_style',
      'Tonal spot',
    )) {
      'Vibrant' => DynamicSchemeVariant.vibrant,
      'Expressive' => DynamicSchemeVariant.expressive,
      'Fidelity' => DynamicSchemeVariant.fidelity,
      'Monochrome' => DynamicSchemeVariant.monochrome,
      _ => DynamicSchemeVariant.tonalSpot,
    };
    final targetColors = useAlbumColors
        ? ColorScheme.fromSeed(
            seedColor: _artworkSeed ?? song.colors.first,
            brightness: baseTheme.brightness,
            dynamicSchemeVariant: variant,
          )
        : baseTheme.colorScheme;

    return PlayerColorSchemeTransition(
      target: targetColors,
      builder: (context, sheetColors, _) => Theme(
        data: PixelPlayTheme.fromColorScheme(sheetColors),
        child: Builder(
          builder: (themedContext) =>
              _buildSheet(themedContext, controller, sheetColors),
        ),
      ),
    );
  }

  Widget _buildSheet(
    BuildContext context,
    AppController controller,
    ColorScheme colors,
  ) {
    final cast = GoogleCastService.instance;
    final mediaQuery = MediaQuery.of(context);
    final maxPagerHeight =
        (mediaQuery.size.height -
                mediaQuery.viewPadding.top -
                mediaQuery.viewPadding.bottom -
                212)
            .clamp(280.0, 560.0);
    final controlsPagerHeight = 340.0.clamp(280.0, maxPagerHeight);
    final showScanningBadge = _isScanning && _castDeviceCount == 0;
    final totalDeviceCount = _castDeviceCount + _bluetoothDevices.length;
    // Compose's original pager wraps its device list. Flutter's PageView needs
    // a finite height, so mirror that behavior from the known row geometry:
    // Wrap the page tightly around the real list geometry. The 16dp spacer
    // below the PageView already separates the last pill from the tab row, so
    // neither the last row nor the scroll view should add trailing clearance.
    // A newly discovered 76dp pill plus its 12dp inter-row gap then grows the
    // bottom-anchored sheet upward by exactly 88dp.
    final deviceRowsHeight =
        (totalDeviceCount * 76.0) +
        ((totalDeviceCount - 1).clamp(0, totalDeviceCount) * 12.0);
    final populatedDevicesHeight =
        64.0 + (_isScanning ? 21.0 : 0.0) + deviceRowsHeight;
    final devicesPagerHeight =
        (totalDeviceCount > 0
                ? populatedDevicesHeight
                : _isScanning
                ? 313.0
                : 248.0)
            .clamp(152.0, maxPagerHeight);
    final pagerHeight = _selectedTab == 1
        ? devicesPagerHeight
        : controlsPagerHeight;

    return Material(
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListenableBuilder(
        listenable: cast,
        builder: (context, _) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    key: const ValueKey('cast-sheet-handle'),
                    width: 32,
                    height: 4,
                    decoration: ShapeDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: .4),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 6, right: 8),
                        child: Text(
                          'Connect device',
                          key: const ValueKey('cast-sheet-title'),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w400,
                                fontSize: 24,
                              ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: showScanningBadge
                            ? Padding(
                                key: const ValueKey('cast-scanning-badge'),
                                padding: const EdgeInsets.only(top: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: ShapeDecoration(
                                    color: colors.primary.withValues(
                                      alpha: .08,
                                    ),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.refresh_rounded,
                                        size: 14,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Scanning nearby',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: colors.primary),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('cast-scanning-idle'),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Content Area PageView
                AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 280),
                  curve: Curves.fastOutSlowIn,
                  height: pagerHeight,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() => _selectedTab = page);
                    },
                    children: [
                      // Tab 0: CONTROLS
                      _buildControlsTab(context, controller, cast, colors),

                      // Tab 1: DEVICES
                      _buildDevicesTab(context, controller, cast, colors),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Bottom Segmented Control Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 68,
                    padding: const EdgeInsets.all(5),
                    decoration: ShapeDecoration(
                      color: colors.surfaceContainerHigh,
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SegmentTabButton(
                            label: 'CONTROLS',
                            icon: Icons.speaker_rounded,
                            isSelected: _selectedTab == 0,
                            onTap: () => _onTabSelected(0),
                          ),
                        ),
                        Expanded(
                          child: _SegmentTabButton(
                            label: 'DEVICES',
                            icon: Icons.devices,
                            isSelected: _selectedTab == 1,
                            onTap: () => _onTabSelected(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlsTab(
    BuildContext context,
    AppController controller,
    GoogleCastService cast,
    ColorScheme colors,
  ) {
    final isPlaying = controller.isPlaying;
    final isCastConnected = cast.connected;
    final isRemote = isCastConnected || cast.connecting;
    final isBt = _isBluetoothActive && !isRemote;
    final phoneVolume = (_mediaVolumeLevel / _mediaVolumeMax).clamp(0.0, 1.0);

    final deviceTitle = isRemote
        ? (cast.routeName ?? 'Cast Device')
        : isBt
        ? (_bluetoothName ?? 'Bluetooth Audio')
        : 'This phone';

    final deviceSubtitle = isRemote
        ? 'Google Cast • Connected'
        : isBt
        ? 'Bluetooth output • ${isPlaying ? "Playing" : "Paused"}'
        : 'Local playback • ${isPlaying ? "Playing" : "Paused"}';

    final deviceIcon = isRemote
        ? Icons.cast_connected_rounded
        : isBt
        ? Icons.bluetooth_audio_rounded
        : Icons.headphones_rounded;
    final normalizedDeviceSubtitle = deviceSubtitle.replaceAll(
      '\u00e2\u20ac\u00a2',
      '•',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Active Device Hero Card
          Material(
            color: colors.tertiaryContainer,
            elevation: 6,
            shadowColor: colors.shadow,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedSuperellipseBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(42),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(42),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: ShapeDecoration(
                          color: colors.onTertiaryContainer.withValues(
                            alpha: 0.12,
                          ),
                          shape: const CircleBorder(),
                        ),
                        child: cast.connecting
                            ? CircularProgressIndicator(
                                strokeWidth: 4,
                                color: colors.onTertiaryContainer,
                                backgroundColor: colors.onTertiaryContainer
                                    .withValues(alpha: .2),
                              )
                            : Icon(
                                deviceIcon,
                                color: colors.onTertiaryContainer,
                                size: 24,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deviceTitle,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.onTertiaryContainer,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              normalizedDeviceSubtitle,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.onTertiaryContainer),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isRemote) ...[
                              const SizedBox(height: 4),
                              FilledButton.icon(
                                onPressed: cast.connecting
                                    ? null
                                    : () => unawaited(cast.disconnect()),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 46),
                                  backgroundColor: colors.surfaceContainerLow,
                                  foregroundColor: colors.onErrorContainer,
                                  shape: const StadiumBorder(),
                                ),
                                icon: const Icon(
                                  Icons.cast_connected_rounded,
                                  size: 22,
                                ),
                                label: const Text('Disconnect'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isRemote ? 'Device volume' : 'Phone volume',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.onTertiaryContainer,
                        ),
                      ),
                      Text(
                        '${((isCastConnected ? cast.deviceVolume : phoneVolume) * 100).round()}%',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colors.onTertiaryContainer),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 30,
                      trackShape: const GappedSliderTrackShape(),
                      trackGap: 6,
                      thumbShape: _VolumeSliderThumbShape(),
                      activeTrackColor: colors.onTertiaryContainer,
                      inactiveTrackColor: colors.onTertiary.withValues(
                        alpha: 0.2,
                      ),
                      thumbColor: colors.onTertiaryContainer,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: isCastConnected ? cast.deviceVolume : phoneVolume,
                      onChanged: cast.connecting
                          ? null
                          : (value) {
                              final step = isCastConnected
                                  ? (value * 20).round()
                                  : (value * _mediaVolumeMax).round();
                              if (step != _lastVolumeStep) {
                                _lastVolumeStep = step;
                                HapticFeedback.selectionClick();
                              }
                              if (isCastConnected) {
                                cast.setDeviceVolume(value);
                              } else {
                                final level = (value * _mediaVolumeMax)
                                    .round()
                                    .clamp(0, _mediaVolumeMax);
                                if (level != _mediaVolumeLevel) {
                                  setState(() => _mediaVolumeLevel = level);
                                  unawaited(_setPhoneMediaVolume(level));
                                }
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Connectivity Header & Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connectivity',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Manage active radios and rescan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  _loadCapabilities();
                  _startDiscovery();
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Quick Settings Tiles (WiFi & Bluetooth)
          Row(
            children: [
              // Wi-Fi Tile
              Expanded(
                child: _QuickSettingTile(
                  icon: _isWifiOn ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  label: _isWifiConnected && _wifiSsid != null
                      ? _wifiSsid!
                      : 'Wi-Fi Connection',
                  subtitle: !_isWifiOn
                      ? 'Off'
                      : _isWifiConnected
                      ? 'Connected'
                      : 'On',
                  isActive: _isWifiOn,
                  onTap: () {
                    const MethodChannel(
                      'com.chiraitori.pixelplay/device_capabilities',
                    ).invokeMethod<void>('openWifiSettings');
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Bluetooth Tile
              Expanded(
                child: _QuickSettingTile(
                  icon: _isBluetoothEnabled
                      ? Icons.bluetooth_rounded
                      : Icons.bluetooth_disabled_rounded,
                  label: _isBluetoothEnabled && _bluetoothName != null
                      ? _bluetoothName!
                      : 'Bluetooth',
                  subtitle: _isBluetoothEnabled ? 'On' : 'Off',
                  isActive: _isBluetoothEnabled,
                  onTap: () {
                    const MethodChannel(
                      'com.chiraitori.pixelplay/device_capabilities',
                    ).invokeMethod<void>('openBluetoothSettings');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesTab(
    BuildContext context,
    AppController controller,
    GoogleCastService cast,
    ColorScheme colors,
  ) {
    return StreamBuilder<List<GoogleCastDevice>>(
      stream: cast.initialized ? cast.devicesStream : null,
      initialData: const [],
      builder: (context, snapshot) {
        final castDevices = snapshot.data ?? const [];
        if (castDevices.length != _castDeviceCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && castDevices.length != _castDeviceCount) {
              setState(() => _castDeviceCount = castDevices.length);
            }
          });
        }
        final hasDevices =
            castDevices.isNotEmpty || _bluetoothDevices.isNotEmpty;
        final remoteSession = cast.connected || cast.connecting;

        final resizeDuration = MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nearby devices',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w400),
                        ),
                        Text(
                          hasDevices ? 'Tap to connect' : 'No devices yet',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _startDiscovery,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surfaceContainerHigh,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              AnimatedSize(
                duration: resizeDuration,
                curve: Curves.fastOutSlowIn,
                alignment: Alignment.topCenter,
                child: _isScanning
                    ? Column(
                        key: const ValueKey('cast-scanning-progress-slot'),
                        children: [
                          ClipRRect(
                            key: const ValueKey('cast-scanning-progress'),
                            borderRadius: BorderRadius.circular(18),
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              value: MediaQuery.disableAnimationsOf(context)
                                  ? .45
                                  : null,
                              color: colors.primary,
                              backgroundColor: colors.primary.withValues(
                                alpha: .12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      )
                    : const SizedBox(
                        key: ValueKey('cast-scanning-progress-idle'),
                        width: double.infinity,
                      ),
              ),
              if (!hasDevices && _isScanning)
                const _CastScanningPlaceholderList(),
              if (!hasDevices && !_isScanning)
                // Searching / Empty State Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: ShapeDecoration(
                    color: colors.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.devices, size: 36, color: colors.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Searching for devices…',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Make sure your TV or speaker is on and sharing the same Wi-Fi network.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              if (hasDevices) ...[
                for (final (index, device) in _bluetoothDevices.indexed)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          index < _bluetoothDevices.length - 1 ||
                              castDevices.isNotEmpty
                          ? 12
                          : 0,
                    ),
                    child: _OutputDeviceTile(
                      key: ValueKey('bluetooth-output-${device.id}'),
                      name: device.name,
                      isBluetooth: true,
                      isSelected: device.isConnected && !remoteSession,
                      isConnected: device.isConnected,
                      batteryPercent: device.batteryPercent,
                      volumePercent: device.isConnected
                          ? ((_mediaVolumeLevel / _mediaVolumeMax) * 100)
                                .round()
                          : null,
                      onTap: () => unawaited(
                        _deviceChannel.invokeMethod<void>(
                          'openBluetoothSettings',
                        ),
                      ),
                    ),
                  ),
                for (final (index, device) in castDevices.indexed)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index < castDevices.length - 1 ? 12 : 0,
                    ),
                    child: _OutputDeviceTile(
                      name: device.friendlyName,
                      isBluetooth: false,
                      isSelected: cast.routeName == device.friendlyName,
                      isConnected:
                          cast.connected &&
                          cast.routeName == device.friendlyName,
                      isConnecting:
                          cast.connecting &&
                          cast.routeName == device.friendlyName,
                      volumePercent:
                          cast.connected &&
                              cast.routeName == device.friendlyName
                          ? (cast.deviceVolume * 100).round()
                          : null,
                      onTap: () async {
                        Navigator.pop(context);
                        final song = controller.currentSong ?? widget.song;
                        if (song != null) {
                          await cast.castSong(
                            device,
                            song,
                            position: controller.position,
                          );
                        }
                      },
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BluetoothAudioDevice {
  const _BluetoothAudioDevice({
    required this.id,
    required this.name,
    required this.isConnected,
    this.batteryPercent,
  });

  factory _BluetoothAudioDevice.fromMap(Map<dynamic, dynamic> map) {
    return _BluetoothAudioDevice(
      id: map['id']?.toString() ?? map['name']?.toString() ?? '',
      name: map['name']?.toString().trim() ?? '',
      isConnected: map['isConnected'] == true,
      batteryPercent: (map['batteryPercent'] as num?)?.toInt(),
    );
  }

  final String id;
  final String name;
  final bool isConnected;
  final int? batteryPercent;
}

class _OutputDeviceTile extends StatelessWidget {
  const _OutputDeviceTile({
    required this.name,
    required this.isBluetooth,
    required this.isSelected,
    required this.isConnected,
    required this.onTap,
    this.isConnecting = false,
    this.volumePercent,
    this.batteryPercent,
    super.key,
  });

  final String name;
  final bool isBluetooth;
  final bool isSelected;
  final bool isConnected;
  final bool isConnecting;
  final int? volumePercent;
  final int? batteryPercent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (containerColor, contentColor) = switch ((isSelected, isBluetooth)) {
      (true, _) => (colors.primaryContainer, colors.onPrimaryContainer),
      (false, true) => (colors.secondaryContainer, colors.onSecondaryContainer),
      _ => (colors.surfaceContainerHighest, colors.onSurface),
    };
    final status = switch ((isBluetooth, isConnected, isConnecting)) {
      (true, true, _) => 'Connected',
      (true, false, _) => 'Available to connect',
      (false, _, true) => 'Connecting',
      (false, true, false) => 'Connected',
      _ => 'Available',
    };
    final metric = batteryPercent ?? volumePercent;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$name, $status',
      child: Material(
        color: containerColor,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 52,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: contentColor.withValues(alpha: .12),
                      shape: isSelected && isConnected
                          ? const StarBorder(
                              points: 8,
                              innerRadiusRatio: .82,
                              pointRounding: .35,
                              valleyRounding: .35,
                            )
                          : const CircleBorder(),
                    ),
                    child: Icon(
                      isBluetooth
                          ? Icons.bluetooth_rounded
                          : Icons.cast_rounded,
                      color: contentColor,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: contentColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: ShapeDecoration(
                          color: contentColor.withValues(alpha: .1),
                          shape: const StadiumBorder(),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isBluetooth
                                  ? Icons.bluetooth_rounded
                                  : Icons.wifi_rounded,
                              size: 14,
                              color: contentColor,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: contentColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected && metric != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    batteryPercent != null
                        ? Icons.battery_full_rounded
                        : Icons.volume_up_rounded,
                    size: 14,
                    color: contentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${metric.clamp(0, 100)}%',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: contentColor),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentTabButton extends StatelessWidget {
  const _SegmentTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final contentColor = isSelected
        ? colors.onPrimary
        : colors.onSurface.withValues(alpha: .9);
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: AnimatedContainer(
          height: double.infinity,
          duration: const Duration(milliseconds: 200),
          curve: Curves.fastOutSlowIn,
          decoration: ShapeDecoration(
            color: isSelected ? colors.primary : colors.surface,
            shape: const StadiumBorder(),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24, color: contentColor),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: contentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickSettingTile extends StatelessWidget {
  const _QuickSettingTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: ShapeDecoration(
                  color: isActive
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.1),
                  shape: const CircleBorder(),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isActive ? colors.onPrimary : colors.onSurface,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CastScanningPlaceholderList extends StatefulWidget {
  const _CastScanningPlaceholderList();

  @override
  State<_CastScanningPlaceholderList> createState() =>
      _CastScanningPlaceholderListState();
}

class _CastScanningPlaceholderListState
    extends State<_CastScanningPlaceholderList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final progress = reduceMotion ? .5 : _shimmer.value;
        final highlightX = -1.8 + (progress * 3.6);
        final decoration = ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment(highlightX - 1, -1),
            end: Alignment(highlightX + 1, 1),
            colors: [
              colors.surfaceContainerHigh,
              colors.surfaceContainerHighest,
              colors.surfaceContainerHigh,
            ],
            stops: const [0, .5, 1],
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(4),
              bottomRight: Radius.circular(28),
              bottomLeft: Radius.circular(4),
            ),
          ),
        );
        return Column(
          children: [
            for (var index = 0; index < 3; index++) ...[
              Container(
                key: ValueKey('cast-scanning-placeholder-$index'),
                height: 68,
                decoration: decoration,
              ),
              if (index < 2) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _VolumeSliderThumbShape extends SliderComponentShape {
  const _VolumeSliderThumbShape();

  static const _thumbSize = Size(4, 36);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => _thumbSize;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final color =
        Color.lerp(
          sliderTheme.disabledThumbColor,
          sliderTheme.thumbColor,
          enableAnimation.value,
        ) ??
        sliderTheme.thumbColor ??
        Colors.white;
    final rect = Rect.fromCenter(
      center: center,
      width: _thumbSize.width,
      height: _thumbSize.height,
    );
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = color,
    );
  }
}
