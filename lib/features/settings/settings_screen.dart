import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import '../player/mini_player.dart';
import '../../shared/widgets/collapsible_common_top_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.onBack,
    required this.onOpenCategory,
    required this.onOpenAccounts,
    required this.onOpenAbout,
    super.key,
  });

  final VoidCallback onBack;
  final ValueChanged<String> onOpenCategory;
  final VoidCallback onOpenAccounts;
  final VoidCallback onOpenAbout;

  static const categories = <SettingsCategoryData>[
    SettingsCategoryData(
      'library',
      'Music Management',
      'Manage folders, refresh library, parsing options',
      Icons.library_music_rounded,
    ),
    SettingsCategoryData(
      'appearance',
      'Appearance',
      'Themes, layout, and visual styles',
      Icons.palette_rounded,
    ),
    SettingsCategoryData(
      'playback',
      'Playback',
      'Audio behavior, crossfade, and background play',
      Icons.music_note_rounded,
    ),
    SettingsCategoryData(
      'behavior',
      'Behavior',
      'Gestures, haptics, and navigation behavior',
      Icons.touch_app_rounded,
    ),
    SettingsCategoryData(
      'ai',
      'AI Integration (β)',
      'AI providers, API keys, and model settings',
      Icons.auto_awesome_rounded,
    ),
    SettingsCategoryData(
      'backup_restore',
      'Backup & Restore',
      'Export and recover your personal app data',
      Icons.upload_file_rounded,
    ),
    SettingsCategoryData(
      'developer',
      'Developer Options',
      'Experimental features and debugging',
      Icons.developer_mode_rounded,
    ),
    SettingsCategoryData(
      'equalizer',
      'Equalizer',
      'Adjust audio frequencies and presets',
      Icons.graphic_eq_rounded,
    ),
    SettingsCategoryData(
      'device_capabilities',
      'Device Capabilities',
      'Audio specs, codecs, and decoder info',
      Icons.developer_board_rounded,
    ),
  ];

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appearController;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = CurvedAnimation(parent: _appearController, curve: Curves.linear);
    _offset = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _appearController,
            curve: const Interval(0, 0.8, curve: Curves.fastOutSlowIn),
          ),
        );
    _appearController.forward();
  }

  @override
  void dispose() {
    _appearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final entries = <_SettingsEntry>[
      for (final category in SettingsScreen.categories)
        _SettingsEntry(
          id: category.id,
          title: category.title,
          subtitle: category.subtitle,
          icon: category.icon,
          onTap: () => widget.onOpenCategory(category.id),
        ),
      _SettingsEntry(
        id: 'accounts',
        title: 'Accounts',
        subtitle: 'Manage Telegram, Google Drive, NetEase, and more services',
        icon: Icons.account_circle_rounded,
        onTap: widget.onOpenAccounts,
      ),
      _SettingsEntry(
        id: 'about',
        title: 'About',
        subtitle: 'App info, version, and credits',
        icon: Icons.info_rounded,
        onTap: widget.onOpenAbout,
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          FadeTransition(
            opacity: _opacity,
            child: SlideTransition(
              position: _offset,
              child: CustomScrollView(
                slivers: [
                  CollapsibleCommonTopBar(
                    title: 'Settings',
                    onBack: widget.onBack,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    sliver: SliverList.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _SettingsCard(
                          entry: entry,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(index == 0 ? 24 : 4),
                            bottom: Radius.circular(
                              index == entries.length - 1 ? 24 : 4,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (controller.currentSong != null)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: MiniPlayer(isNavBarHidden: true),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.entry, required this.borderRadius});

  final _SettingsEntry entry;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final categoryColors = _categoryColors(
      entry.id,
      Theme.of(context).brightness == Brightness.dark,
    );
    return Material(
      color: colors.surfaceContainer,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: entry.onTap,
        child: SizedBox(
          height: 88,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: categoryColors.$1,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(entry.icon, color: categoryColors.$2, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        entry.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color) _categoryColors(String id, bool isDark) {
    if (isDark) {
      return switch (id) {
        'library' => (const Color(0xFF004A77), const Color(0xFFC2E7FF)),
        'appearance' => (const Color(0xFF7D5260), const Color(0xFFFFD8E4)),
        'playback' => (const Color(0xFF633B48), const Color(0xFFFFD8EC)),
        'behavior' => (const Color(0xFF3E4C63), const Color(0xFFD7E3FF)),
        'ai' => (const Color(0xFF004F58), const Color(0xFF88FAFF)),
        'backup_restore' => (const Color(0xFF3B4869), const Color(0xFFD9E2FF)),
        'developer' => (const Color(0xFF324F34), const Color(0xFFCBEFD0)),
        'equalizer' => (const Color(0xFF6E4E13), const Color(0xFFFFDEAC)),
        'device_capabilities' => (
          const Color(0xFF004D61),
          const Color(0xFFACEFEE),
        ),
        'accounts' => (const Color(0xFF37474F), const Color(0xFFBBD9E8)),
        'about' => (const Color(0xFF3F474D), const Color(0xFFDEE3EB)),
        _ => (const Color(0xFF3F474D), const Color(0xFFDEE3EB)),
      };
    }
    return switch (id) {
      'library' => (const Color(0xFFD7E3FF), const Color(0xFF005AC1)),
      'appearance' => (const Color(0xFFFFD8E4), const Color(0xFF631835)),
      'playback' => (const Color(0xFFFFD8EC), const Color(0xFF631B4B)),
      'behavior' => (const Color(0xFFD7E3FF), const Color(0xFF253347)),
      'ai' => (const Color(0xFFCCE8EA), const Color(0xFF004F58)),
      'backup_restore' => (const Color(0xFFD9E2FF), const Color(0xFF27304E)),
      'developer' => (const Color(0xFFCBEFD0), const Color(0xFF042106)),
      'equalizer' => (const Color(0xFFFFDEAC), const Color(0xFF281900)),
      'device_capabilities' => (
        const Color(0xFFACEFEE),
        const Color(0xFF002022),
      ),
      'accounts' => (const Color(0xFFD6EAF5), const Color(0xFF103548)),
      'about' => (const Color(0xFFEFF1F7), const Color(0xFF44474F)),
      _ => (const Color(0xFFEFF1F7), const Color(0xFF44474F)),
    };
  }
}

class SettingsCategoryData {
  const SettingsCategoryData(this.id, this.title, this.subtitle, this.icon);

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _SettingsEntry {
  const _SettingsEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}
