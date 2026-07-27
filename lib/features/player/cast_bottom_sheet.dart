import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/entities.dart' show GoogleCastDevice;

import '../../core/models/song.dart';
import '../../core/services/google_cast_service.dart';
import '../../core/state/app_controller.dart';

Future<void> showCastBottomSheet({
  required BuildContext context,
  required Song? song,
}) async {
  final cast = GoogleCastService.instance;
  await cast.startDiscovery();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _CastBottomSheetContent(song: song),
  );

  await cast.stopDiscovery();
}

class _CastBottomSheetContent extends StatefulWidget {
  const _CastBottomSheetContent({required this.song});

  final Song? song;

  @override
  State<_CastBottomSheetContent> createState() =>
      __CastBottomSheetContentState();
}

class __CastBottomSheetContentState extends State<_CastBottomSheetContent> {
  int _selectedTab = 0; // 0 = CONTROLS, 1 = DEVICES
  late final PageController _pageController;

  bool _isBluetoothActive = false;
  String? _bluetoothName;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTab);
    _loadCapabilities();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCapabilities() async {
    try {
      final map = await const MethodChannel(
        'com.chiraitori.pixelplay/device_capabilities',
      ).invokeMethod<Map>('getCapabilities');
      if (map != null && mounted) {
        setState(() {
          _isBluetoothActive = map['bluetoothActive'] as bool? ?? false;
          _bluetoothName = map['bluetoothName'] as String?;
        });
      }
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final cast = GoogleCastService.instance;
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: cast,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),

              // Title Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Connect device',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 24,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Content Area PageView
              SizedBox(
                height: 320,
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.all(4),
                  decoration: ShapeDecoration(
                    color: colors.surfaceContainerHigh,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SegmentTabButton(
                          label: 'CONTROLS',
                          icon: Icons.tune_rounded,
                          isSelected: _selectedTab == 0,
                          onTap: () => _onTabSelected(0),
                        ),
                      ),
                      Expanded(
                        child: _SegmentTabButton(
                          label: 'DEVICES',
                          icon: Icons.devices_rounded,
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
    final isBt = _isBluetoothActive && !isCastConnected;

    final deviceTitle = isCastConnected
        ? (cast.routeName ?? 'Cast Device')
        : isBt
            ? (_bluetoothName ?? 'Bluetooth Audio')
            : 'This phone';

    final deviceSubtitle = isCastConnected
        ? 'Google Cast • Connected'
        : isBt
            ? 'Bluetooth output • ${isPlaying ? "Playing" : "Paused"}'
            : 'Local playback • ${isPlaying ? "Paused" : "Paused"}';

    final deviceIcon = isCastConnected
        ? Icons.cast_connected_rounded
        : isBt
            ? Icons.bluetooth_audio_rounded
            : Icons.headphones_rounded;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Active Device Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: ShapeDecoration(
              color: colors.tertiaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: ShapeDecoration(
                        color: colors.onTertiaryContainer.withValues(alpha: 0.14),
                        shape: const CircleBorder(),
                      ),
                      child: Icon(
                        deviceIcon,
                        color: colors.onTertiaryContainer,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deviceTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.onTertiaryContainer,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            deviceSubtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colors.onTertiaryContainer
                                      .withValues(alpha: 0.8),
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Volume Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Phone volume',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colors.onTertiaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '${(_volume * 100).round()}%',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.onTertiaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Custom Volume Slider
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 28,
                      thumbShape: SliderComponentShape.noThumb,
                      activeTrackColor: colors.onTertiaryContainer,
                      inactiveTrackColor:
                          colors.onTertiaryContainer.withValues(alpha: 0.2),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: _volume,
                      onChanged: (val) {
                        setState(() => _volume = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Connectivity Header & Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connectivity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Manage active radios and rescan',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  _loadCapabilities();
                  cast.startDiscovery();
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
                  icon: Icons.wifi_rounded,
                  label: 'Wi-Fi Connection',
                  subtitle: 'Connected',
                  isActive: true,
                  onTap: () {
                    const MethodChannel(
                      'com.chiraitori.pixelplay/device_capabilities',
                    ).invokeMethod<void>('openAudioOutputSettings');
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Bluetooth Tile
              Expanded(
                child: _QuickSettingTile(
                  icon: _isBluetoothActive
                      ? Icons.bluetooth_rounded
                      : Icons.bluetooth_disabled_rounded,
                  label: _isBluetoothActive && _bluetoothName != null
                      ? _bluetoothName!
                      : 'Bluetooth',
                  subtitle: _isBluetoothActive ? 'On' : 'Off',
                  isActive: _isBluetoothActive,
                  onTap: () {
                    const MethodChannel(
                      'com.chiraitori.pixelplay/device_capabilities',
                    ).invokeMethod<void>('openAudioOutputSettings');
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
        final devices = snapshot.data ?? const [];

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nearby devices',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        devices.isNotEmpty ? 'Tap to connect' : 'No devices yet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => cast.startDiscovery(),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surfaceContainerHigh,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (devices.isEmpty)
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
                      Icon(
                        Icons.devices_other_rounded,
                        size: 44,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Searching for devices…',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
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
                )
              else
                ...devices.map(
                  (device) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: ShapeDecoration(
                      color: colors.surfaceContainerHigh,
                      shape: const StadiumBorder(),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.cast_rounded, color: colors.primary),
                      title: Text(
                        device.friendlyName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(device.modelName ?? 'Google Cast'),
                      trailing: cast.routeName == device.friendlyName
                          ? Icon(Icons.check_circle_rounded, color: colors.primary)
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        Navigator.pop(context);
                        if (widget.song != null) {
                          await cast.castSong(
                            device,
                            widget.song!,
                            position: controller.position,
                          );
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.fastOutSlowIn,
        decoration: ShapeDecoration(
          color: isSelected ? colors.primaryContainer : Colors.transparent,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
              ),
            ),
          ],
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
              Container(
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
