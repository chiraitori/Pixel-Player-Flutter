import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';

class ArtistSettingsScreen extends StatefulWidget {
  const ArtistSettingsScreen({
    required this.onOpenCharacterDelimiters,
    required this.onOpenWordDelimiters,
    super.key,
  });

  final VoidCallback onOpenCharacterDelimiters;
  final VoidCallback onOpenWordDelimiters;

  @override
  State<ArtistSettingsScreen> createState() => _ArtistSettingsScreenState();
}

class _ArtistSettingsScreenState extends State<ArtistSettingsScreen> {
  bool _rescanning = false;

  Future<void> _rescan(AppController controller) async {
    setState(() => _rescanning = true);
    await controller.refreshLibrary();
    controller.setBoolSetting('artist_rescan_required', false);
    if (mounted) setState(() => _rescanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final rescanRequired = controller.boolSetting(
      'artist_rescan_required',
      false,
    );
    final characterDelimiters = controller.stringListSetting(
      'artist_character_delimiters',
      AppController.defaultArtistDelimiters,
    );
    final wordDelimiters = controller.stringListSetting(
      'artist_word_delimiters',
      AppController.defaultArtistWordDelimiters,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(pinned: true, title: Text('Artist parsing')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 56),
            sliver: SliverList.list(
              children: [
                if (rescanRequired) ...[
                  _RescanCard(
                    loading: _rescanning,
                    onPressed: _rescanning ? null : () => _rescan(controller),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Splitting rules',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsGroup(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.data_array_rounded),
                      title: const Text('Character delimiters'),
                      subtitle: Text(_summary(characterDelimiters)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: widget.onOpenCharacterDelimiters,
                    ),
                    ListTile(
                      leading: const Icon(Icons.abc_rounded),
                      title: const Text('Word delimiters'),
                      subtitle: Text(_summary(wordDelimiters)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: widget.onOpenWordDelimiters,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Artist metadata',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsGroup(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.call_split_rounded),
                      title: const Text('Split multiple artists'),
                      subtitle: const Text(
                        'Create separate artist entries from one audio tag',
                      ),
                      value: controller.boolSetting(
                        'artist_extract_from_title',
                        true,
                      ),
                      onChanged: (value) {
                        controller.setBoolSetting(
                          'artist_extract_from_title',
                          value,
                        );
                        controller.setBoolSetting(
                          'artist_rescan_required',
                          true,
                        );
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.album_rounded),
                      title: const Text('Prefer album artist'),
                      subtitle: const Text(
                        'Group album tracks using album-artist metadata',
                      ),
                      value: controller.boolSetting(
                        'artist_group_by_album_artist',
                        false,
                      ),
                      onChanged: (value) {
                        controller.setBoolSetting(
                          'artist_group_by_album_artist',
                          value,
                        );
                        controller.setBoolSetting(
                          'artist_rescan_required',
                          true,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  color: colors.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_rounded,
                          color: colors.onTertiaryContainer,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Example',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colors.onTertiaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '“Artist A feat. Artist B; Artist C” becomes '
                                'three artist entries with the default rules.',
                                style: TextStyle(
                                  color: colors.onTertiaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _summary(List<String> values) {
    if (values.isEmpty) return 'None configured';
    return values.map((value) => '“$value”').join('  •  ');
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Material(
        color: colors.surfaceContainer,
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1)
                const Divider(height: 1, indent: 64),
            ],
          ],
        ),
      ),
    );
  }
}

class _RescanCard extends StatelessWidget {
  const _RescanCard({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync_rounded, color: colors.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Library rescan required',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Apply the new parsing rules to artists already in your library.',
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onPressed,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(loading ? 'Rescanning…' : 'Rescan library'),
            ),
          ],
        ),
      ),
    );
  }
}
