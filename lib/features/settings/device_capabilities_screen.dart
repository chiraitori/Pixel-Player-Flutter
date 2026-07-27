import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/widgets/collapsible_common_top_bar.dart';

class DeviceCapabilitiesScreen extends StatefulWidget {
  const DeviceCapabilitiesScreen({super.key});

  @override
  State<DeviceCapabilitiesScreen> createState() =>
      _DeviceCapabilitiesScreenState();
}

class _DeviceCapabilitiesScreenState extends State<DeviceCapabilitiesScreen> {
  static const _channel = MethodChannel(
    'com.chiraitori.pixelplay/device_capabilities',
  );
  late Future<Map<String, dynamic>> _capabilities = _load();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CollapsibleCommonTopBar(
            title: 'Device Capabilities',
            onBack: () => Navigator.maybePop(context),
            expandedHeight: 200,
            maxLines: 2,
            actions: [
              IconButton(
                onPressed: () => setState(() => _capabilities = _load()),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _capabilities,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final data = snapshot.data!;
              final decoders = List<String>.from(
                data['decoderTypes'] as List? ?? const [],
              );
              final groups = _groups(data, decoders);
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                sliver: SliverList.list(
                  children: [
                    _DeviceSummary(data: data),
                    for (final group in groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 22, 12, 8),
                        child: Text(
                          group.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Card(
                        child: Column(
                          children: [
                            for (final item in group.items)
                              ListTile(
                                leading: Icon(item.icon),
                                title: Text(item.title),
                                subtitle: Text(item.subtitle),
                                trailing: Icon(
                                  item.supported
                                      ? Icons.check_circle_rounded
                                      : Icons.info_outline_rounded,
                                  color: item.supported
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _load() async {
    try {
      return Map<String, dynamic>.from(
        await _channel.invokeMapMethod<String, dynamic>('getCapabilities') ??
            const {},
      );
    } on MissingPluginException {
      final info = await DeviceInfoPlugin().deviceInfo;
      return <String, dynamic>{
        'manufacturer': info.data['manufacturer'] ?? 'Flutter',
        'model': info.data['model'] ?? 'Test device',
        'sdk': info.data['version.sdkInt'] ?? 0,
        'release': info.data['version.release'] ?? '',
        'abis': const <String>[],
        'decoderTypes': const <String>[],
        'dynamicColor': false,
        'notificationsEnabled': false,
        'exactAlarms': false,
        'batteryOptimized': false,
        'automotive': false,
        'watch': false,
        'lowLatencyAudio': false,
        'proAudio': false,
      };
    }
  }

  List<_CapabilityGroup> _groups(
    Map<String, dynamic> data,
    List<String> decoders,
  ) {
    bool supports(String fragment) =>
        decoders.any((type) => type.contains(fragment));
    final sampleRate = data['outputSampleRate']?.toString() ?? 'Unknown';
    final buffer = data['framesPerBuffer']?.toString() ?? 'Unknown';
    return [
      _CapabilityGroup('Audio playback', [
        const _Capability(
          'Gapless playback',
          'Provided by the PixelPlay playback queue',
          Icons.compare_arrows_rounded,
          true,
        ),
        const _Capability(
          'Crossfade',
          'Dual-player transitions are available in DJ Space',
          Icons.multiline_chart_rounded,
          true,
        ),
        const _Capability(
          'ReplayGain / equalizer',
          'Android audio effects pipeline',
          Icons.volume_down_rounded,
          true,
        ),
        _Capability(
          'Low-latency audio',
          'Output: $sampleRate Hz, $buffer frames per buffer',
          Icons.memory_rounded,
          data['lowLatencyAudio'] == true,
        ),
        _Capability(
          'Pro audio feature',
          data['proAudio'] == true ? 'Reported by Android' : 'Not reported',
          Icons.high_quality_rounded,
          data['proAudio'] == true,
        ),
      ]),
      _CapabilityGroup('Audio decoders', [
        _Capability(
          'MP3',
          supports('mpeg') ? 'Hardware/software decoder found' : 'Not reported',
          Icons.audio_file_rounded,
          supports('mpeg'),
        ),
        _Capability(
          'AAC',
          supports('mp4a') || supports('aac')
              ? 'Hardware/software decoder found'
              : 'Not reported',
          Icons.audio_file_rounded,
          supports('mp4a') || supports('aac'),
        ),
        _Capability(
          'FLAC',
          supports('flac') ? 'Decoder found' : 'Not reported',
          Icons.high_quality_rounded,
          supports('flac'),
        ),
        _Capability(
          'Opus',
          supports('opus') ? 'Decoder found' : 'Not reported',
          Icons.graphic_eq_rounded,
          supports('opus'),
        ),
        _Capability(
          'Vorbis',
          supports('vorbis') ? 'Decoder found' : 'Not reported',
          Icons.graphic_eq_rounded,
          supports('vorbis'),
        ),
      ]),
      _CapabilityGroup('Android integration', [
        _Capability(
          'Dynamic color',
          data['dynamicColor'] == true
              ? 'Material You colors available'
              : 'PixelPlay fallback palette',
          Icons.palette_rounded,
          data['dynamicColor'] == true,
        ),
        _Capability(
          'Media notifications',
          data['notificationsEnabled'] == true
              ? 'Notifications enabled'
              : 'Notifications disabled',
          Icons.notifications_rounded,
          data['notificationsEnabled'] == true,
        ),
        _Capability(
          'Exact alarms',
          data['exactAlarms'] == true
              ? 'Sleep timer can fire precisely'
              : 'Permission required',
          Icons.alarm_rounded,
          data['exactAlarms'] == true,
        ),
        _Capability(
          'Battery optimization',
          data['batteryOptimized'] == true
              ? 'PixelPlay is battery optimized'
              : 'Unrestricted background playback',
          Icons.battery_saver_rounded,
          data['batteryOptimized'] != true,
        ),
        _Capability(
          'Android Auto',
          data['automotive'] == true
              ? 'Automotive device detected'
              : 'Standard Android device',
          Icons.directions_car_rounded,
          data['automotive'] == true,
        ),
        _Capability(
          'Wear OS',
          data['watch'] == true ? 'Watch device detected' : 'Phone/tablet',
          Icons.watch_rounded,
          data['watch'] == true,
        ),
      ]),
    ];
  }
}

class _DeviceSummary extends StatelessWidget {
  const _DeviceSummary({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final abis = List<String>.from(data['abis'] as List? ?? const []);
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: const Icon(Icons.phone_android_rounded, size: 38),
        title: Text(
          '${data['manufacturer'] ?? ''} ${data['model'] ?? ''}'.trim(),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Android ${data['release'] ?? ''} (API ${data['sdk'] ?? '?'})'
          '${abis.isEmpty ? '' : '\n${abis.join(', ')}'}',
        ),
      ),
    );
  }
}

class _CapabilityGroup {
  const _CapabilityGroup(this.title, this.items);

  final String title;
  final List<_Capability> items;
}

class _Capability {
  const _Capability(this.title, this.subtitle, this.icon, this.supported);

  final String title;
  final String subtitle;
  final IconData icon;
  final bool supported;
}
