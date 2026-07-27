import 'package:flutter/material.dart';

import '../../../core/state/app_controller.dart';

Future<void> showStreamingProviderSheet({
  required BuildContext context,
  required VoidCallback onOpenAccounts,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => _StreamingProviderSheet(
      onOpenAccounts: () {
        Navigator.pop(sheetContext);
        onOpenAccounts();
      },
    ),
  );
}

class _StreamingProviderSheet extends StatelessWidget {
  const _StreamingProviderSheet({required this.onOpenAccounts});

  final VoidCallback onOpenAccounts;

  static const _providers = [
    _Provider(
      id: 'telegram',
      title: 'Telegram',
      subtitle: 'Stream from channels & chats',
      icon: Icons.telegram,
      color: Color(0xFF2AABEE),
    ),
    _Provider(
      id: 'google_drive',
      title: 'Google Drive',
      subtitle: 'Coming soon',
      icon: Icons.add_to_drive_rounded,
      color: Color(0xFF4285F4),
      enabled: false,
    ),
    _Provider(
      id: 'navidrome',
      title: 'Subsonic',
      subtitle: 'Connect Navidrome & others',
      connectedSubtitle: 'Connected • Navidrome/Airsonic',
      icon: Icons.dns_rounded,
      color: Color(0xFFE8A54B),
    ),
    _Provider(
      id: 'jellyfin',
      title: 'Jellyfin',
      subtitle: 'Connect your Jellyfin server',
      connectedSubtitle: 'Connected',
      icon: Icons.play_circle_rounded,
      color: Color(0xFF00A4DC),
    ),
    _Provider(
      id: 'netease',
      title: 'Netease Music',
      subtitle: 'Sign in to stream',
      connectedSubtitle: 'Connected',
      icon: Icons.cloud_rounded,
      color: Color(0xFFE85959),
    ),
    _Provider(
      id: 'qq_music',
      title: 'QQ Music',
      subtitle: 'Sign in to stream',
      connectedSubtitle: 'Connected',
      icon: Icons.music_note_rounded,
      color: Color(0xFF31C27C),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cloud streaming',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a provider to connect or manage your music.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    for (var index = 0; index < _providers.length; index++) ...[
                      if (index > 0) const SizedBox(height: 4),
                      _ProviderRow(
                        provider: _providers[index],
                        isConnected: controller.boolSetting(
                          'account_${_providers[index].id}_connected',
                          false,
                        ),
                        onTap: onOpenAccounts,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.provider,
    required this.isConnected,
    required this.onTap,
  });

  final _Provider provider;
  final bool isConnected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = provider.enabled;
    final containerColor = !enabled
        ? colors.surfaceContainerLowest
        : isConnected
        ? colors.surfaceContainerHighest
        : colors.surfaceContainerHigh;
    final arrowContainer = !enabled
        ? colors.surfaceContainerHighest
        : isConnected
        ? colors.primaryContainer
        : colors.surfaceBright;
    final arrowColor = !enabled
        ? colors.onSurfaceVariant.withValues(alpha: .45)
        : isConnected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant.withValues(alpha: .72);

    return Opacity(
      opacity: enabled ? 1 : .62,
      child: Material(
        color: containerColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ListTile(
            leading: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: provider.color.withValues(alpha: enabled ? .14 : .1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(provider.icon, size: 22, color: provider.color),
            ),
            title: Text(
              provider.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              isConnected
                  ? provider.connectedSubtitle ?? provider.subtitle
                  : provider.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isConnected ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
            trailing: Material(
              color: arrowContainer,
              shape: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: 26,
                  color: arrowColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Provider {
  const _Provider({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.connectedSubtitle,
    this.enabled = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? connectedSubtitle;
  final IconData icon;
  final Color color;
  final bool enabled;
}
