import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../data/providers/google_drive/google_drive_auth_service.dart';
import '../../data/providers/jellyfin/jellyfin_auth_repository.dart';
import '../../data/providers/navidrome/navidrome_auth_repository.dart';
import '../../shared/widgets/collapsible_common_top_bar.dart';
import 'google_drive_connect_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  static const services = <_Service>[
    _Service(
      id: 'telegram',
      name: 'Telegram',
      subtitle: 'Active Telegram session',
      icon: Icons.telegram,
      color: Color(0xFF2AABEE),
      credentialLabel: 'Phone number or session token',
    ),
    _Service(
      id: 'google_drive',
      name: 'Google Drive',
      subtitle: 'Play audio stored in your Drive',
      icon: Icons.add_to_drive_rounded,
      color: Color(0xFF34A853),
      credentialLabel: '',
    ),
    _Service(
      id: 'netease',
      name: 'Netease Music',
      subtitle: 'Netease account connected',
      icon: Icons.cloud_rounded,
      color: Color(0xFFE53935),
      credentialLabel: 'MUSIC_U cookie',
    ),
    _Service(
      id: 'qq_music',
      name: 'QQ Music',
      subtitle: 'QQ Music account connected',
      icon: Icons.music_note_rounded,
      color: Color(0xFF31C27C),
      credentialLabel: 'QQ Music cookie',
    ),
    _Service(
      id: 'navidrome',
      name: 'Subsonic',
      subtitle: 'Subsonic account connected',
      icon: Icons.dns_rounded,
      color: Color(0xFF6750A4),
      credentialLabel: 'Password',
      requiresServer: true,
    ),
    _Service(
      id: 'jellyfin',
      name: 'Jellyfin',
      subtitle: 'Jellyfin account connected',
      icon: Icons.play_circle_rounded,
      color: Color(0xFFAA5CC3),
      credentialLabel: 'Password',
      requiresServer: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final connected = services
        .where(
          (service) =>
              controller.boolSetting('account_${service.id}_connected', false),
        )
        .toList(growable: false);
    final disconnected = services
        .where((service) => !connected.contains(service))
        .toList(growable: false);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CollapsibleCommonTopBar(
            title: 'Accounts',
            onBack: () => Navigator.maybePop(context),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            sliver: SliverList.list(
              children: [
                _AccountsHero(
                  connectedCount: connected.length,
                  availableCount: services.length,
                ),
                if (connected.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
                    child: Text(
                      'Linked services',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  for (final service in connected) ...[
                    _ConnectedAccountCard(
                      service: service,
                      label: controller.stringSetting(
                        'account_${service.id}_label',
                        service.name,
                      ),
                      syncedContentLabel: _syncedContentLabel(
                        controller,
                        service,
                      ),
                      onManage: () =>
                          _showAccountDialog(context, service, controller),
                      onLogout: () {
                        if (service.id == 'google_drive') {
                          unawaited(
                            GoogleDriveAuthService.instance.disconnect(),
                          );
                          controller.clearGoogleDriveLibrary();
                        }
                        controller.setBoolSetting(
                          'account_${service.id}_connected',
                          false,
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                ] else
                  _EmptyAccountsCard(
                    services: disconnected,
                    onConnect: (service) =>
                        _showAccountDialog(context, service, controller),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _syncedContentLabel(AppController controller, _Service service) {
    if (service.id == 'google_drive') {
      final hasFolder = controller
          .stringSetting('google_drive_folder_id', '')
          .isNotEmpty;
      return hasFolder ? '1 synced folder' : '0 synced folders';
    }

    final source = switch (service.id) {
      'telegram' => SongSource.telegram,
      'netease' => SongSource.netease,
      'qq_music' => SongSource.qqMusic,
      'navidrome' => SongSource.navidrome,
      'jellyfin' => SongSource.jellyfin,
      _ => null,
    };
    final count = source == null
        ? 0
        : controller.songs.where((song) => song.source == source).length;
    if (service.id == 'telegram') {
      return count == 1 ? '1 synced channel' : '$count synced channels';
    }
    return count == 1 ? '1 synced playlist' : '$count synced playlists';
  }

  Future<void> _showAccountDialog(
    BuildContext context,
    _Service service,
    AppController controller,
  ) async {
    if (service.id == 'google_drive') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => const GoogleDriveConnectScreen(),
        ),
      );
      return;
    }
    final server = TextEditingController(
      text: controller.stringSetting('account_${service.id}_server', ''),
    );
    final username = TextEditingController(
      text: controller.stringSetting('account_${service.id}_username', ''),
    );
    final credential = TextEditingController(
      text: controller.stringSetting('account_${service.id}_credential', ''),
    );
    var testing = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Connect ${service.name}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (service.requiresServer) ...[
                    TextField(
                      controller: server,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'https://music.example.com',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: username,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: credential,
                    obscureText:
                        service.id == 'navidrome' || service.id == 'jellyfin',
                    decoration: InputDecoration(
                      labelText: service.credentialLabel,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: testing ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: testing
                  ? null
                  : () async {
                      setDialogState(() {
                        testing = true;
                        error = null;
                      });
                      try {
                        final label = await _validateService(
                          service,
                          server.text.trim(),
                          username.text.trim(),
                          credential.text.trim(),
                        );
                        controller
                          ..setStringSetting(
                            'account_${service.id}_server',
                            server.text.trim(),
                          )
                          ..setStringSetting(
                            'account_${service.id}_username',
                            username.text.trim(),
                          )
                          ..setStringSetting(
                            'account_${service.id}_credential',
                            credential.text.trim(),
                          )
                          ..setStringSetting(
                            'account_${service.id}_label',
                            label,
                          )
                          ..setBoolSetting(
                            'account_${service.id}_connected',
                            true,
                          );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (exception) {
                        setDialogState(() {
                          testing = false;
                          error = exception.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                        });
                      }
                    },
              child: testing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
    server.dispose();
    username.dispose();
    credential.dispose();
  }

  Future<String> _validateService(
    _Service service,
    String server,
    String username,
    String credential,
  ) async {
    if (credential.isEmpty) {
      throw Exception('${service.credentialLabel} is required');
    }
    if (!service.requiresServer) {
      return service.subtitle;
    }
    final base = Uri.tryParse(server);
    if (base == null || !base.hasScheme || base.host.isEmpty) {
      throw Exception('Enter a valid server URL');
    }
    if (username.isEmpty) throw Exception('Username is required');

    return switch (service.id) {
      'navidrome' => const NavidromeAuthRepository().validate(
        server: base,
        username: username,
        password: credential,
      ),
      'jellyfin' => const JellyfinAuthRepository().validate(
        server: base,
        username: username,
        password: credential,
      ),
      _ => username,
    };
  }
}

class _AccountsHero extends StatelessWidget {
  const _AccountsHero({
    required this.connectedCount,
    required this.availableCount,
  });

  final int connectedCount;
  final int availableCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surfaceContainer,
      elevation: 0,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connected Accounts',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage linked providers and keep each integration under your '
              'control.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _HeroStat(label: 'Active', value: '$connectedCount'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroStat(
                    label: 'Available',
                    value: '$availableCount',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: ShapeDecoration(
        color: colors.surfaceContainerLow,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ConnectedAccountCard extends StatelessWidget {
  const _ConnectedAccountCard({
    required this.service,
    required this.label,
    required this.syncedContentLabel,
    required this.onManage,
    required this.onLogout,
  });

  final _Service service;
  final String label;
  final String syncedContentLabel;
  final VoidCallback onManage;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = _ServicePalette.forService(colors, service.id);
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerHigh,
      elevation: 0,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _ServiceIcon(service: service, palette: palette),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        label,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: palette.statusContainer,
                    shape: const RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      'Connected',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.surfaceContainerLow,
                shape: const RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(Icons.sync_rounded, size: 16, color: palette.iconTint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        syncedContentLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: colors.outlineVariant.withValues(alpha: .28)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.tonalIcon(
                onPressed: onManage,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.primaryActionContainer,
                  foregroundColor: palette.primaryActionTint,
                  shape: const RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text(
                  'Open Service',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.primaryActionTint,
                  side: BorderSide(
                    color: palette.primaryActionTint.withValues(alpha: .45),
                  ),
                  shape: const RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Log out',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAccountsCard extends StatelessWidget {
  const _EmptyAccountsCard({required this.services, required this.onConnect});

  final List<_Service> services;
  final ValueChanged<_Service> onConnect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 14),
      color: colors.surfaceContainer,
      elevation: 0,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No linked accounts yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Connect a provider to manage it from this screen.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (final service in services) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => onConnect(service),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                  ),
                  icon: Icon(service.icon, size: 18),
                  label: Text('Connect ${service.name}'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({required this.service, required this.palette});

  final _Service service;
  final _ServicePalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.iconContainer,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(service.icon, color: palette.iconTint, size: 20),
      ),
    );
  }
}

class _ServicePalette {
  const _ServicePalette({
    required this.iconContainer,
    required this.iconTint,
    required this.statusContainer,
    required this.primaryActionContainer,
    required this.primaryActionTint,
  });

  factory _ServicePalette.forService(ColorScheme colors, String id) {
    return switch (id) {
      'telegram' => _ServicePalette(
        iconContainer: colors.primaryContainer,
        iconTint: colors.onPrimaryContainer,
        statusContainer: const Color(0xFFC9F8E6),
        primaryActionContainer: colors.primaryContainer,
        primaryActionTint: colors.onPrimaryContainer,
      ),
      'google_drive' => _ServicePalette(
        iconContainer: colors.secondaryContainer,
        iconTint: colors.onSecondaryContainer,
        statusContainer: const Color(0xFFD7F4D0),
        primaryActionContainer: colors.secondaryContainer,
        primaryActionTint: colors.onSecondaryContainer,
      ),
      'netease' => _ServicePalette(
        iconContainer: colors.errorContainer,
        iconTint: colors.onErrorContainer,
        statusContainer: const Color(0xFFFFE3E1),
        primaryActionContainer: colors.errorContainer,
        primaryActionTint: colors.onErrorContainer,
      ),
      'qq_music' => _ServicePalette(
        iconContainer: colors.tertiaryContainer,
        iconTint: colors.onTertiaryContainer,
        statusContainer: const Color(0xFFFFF0C7),
        primaryActionContainer: colors.tertiaryContainer,
        primaryActionTint: colors.onTertiaryContainer,
      ),
      'navidrome' || 'jellyfin' => const _ServicePalette(
        iconContainer: Color(0xFFE3F2FD),
        iconTint: Color(0xFF1565C0),
        statusContainer: Color(0xFFE1F5FE),
        primaryActionContainer: Color(0xFFE3F2FD),
        primaryActionTint: Color(0xFF1565C0),
      ),
      _ => _ServicePalette(
        iconContainer: colors.surfaceContainerHighest,
        iconTint: colors.onSurfaceVariant,
        statusContainer: colors.secondaryContainer,
        primaryActionContainer: colors.secondaryContainer,
        primaryActionTint: colors.onSecondaryContainer,
      ),
    };
  }

  final Color iconContainer;
  final Color iconTint;
  final Color statusContainer;
  final Color primaryActionContainer;
  final Color primaryActionTint;
}

class _Service {
  const _Service({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.credentialLabel,
    this.requiresServer = false,
  });

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String credentialLabel;
  final bool requiresServer;
}
