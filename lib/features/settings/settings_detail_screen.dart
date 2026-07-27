import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/data/ai/gemini_ai_client.dart';
import '../../core/data/lyrics_service.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/collapsible_common_top_bar.dart';
import '../shell/player_internal_navigation_bar.dart';
import 'settings_screen.dart';
import 'widgets/settings_components.dart';

class SettingsDetailScreen extends StatefulWidget {
  const SettingsDetailScreen({
    required this.categoryId,
    required this.onOpenScreen,
    super.key,
  });

  final String categoryId;
  final ValueChanged<String> onOpenScreen;

  @override
  State<SettingsDetailScreen> createState() => _SettingsDetailScreenState();
}

class _SettingsDetailScreenState extends State<SettingsDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final category = SettingsScreen.categories.firstWhere(
      (item) => item.id == widget.categoryId,
      orElse: () => SettingsScreen.categories.first,
    );
    final sections = _sectionsFor(category.id);
    final isLongTitle = category.title.length > 13;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CollapsibleCommonTopBar(
            title: category.title,
            onBack: () => Navigator.maybePop(context),
            expandedHeight: isLongTitle ? 200 : 180,
            maxLines: isLongTitle ? 2 : 1,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            sliver: SliverList.list(
              children: [
                for (final section in sections) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text(
                      section.title,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  _SettingsGroup(
                    children: [
                      for (final item in section.items)
                        _buildItem(context, item),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, _SettingItem item) {
    final controller = AppScope.of(context);
    final settingKey = _settingKey(item);
    if (settingKey == 'playback_replay_gain_mode' &&
        !controller.boolSetting('playback_replay_gain_enabled', false)) {
      return const SizedBox.shrink();
    }
    if (settingKey == 'playback_crossfade_duration_ms' &&
        !controller.boolSetting('playback_crossfade_enabled', false)) {
      return const SizedBox.shrink();
    }
    if (item.kind == _SettingKind.slider) {
      final value = controller.doubleSetting(settingKey, item.initialDouble);
      return SettingsSliderItem(
        label: item.title,
        value: value,
        min: item.min,
        max: item.max,
        divisions: item.divisions,
        valueText: (next) {
          final scaled = next / item.valueDivisor;
          final label = item.valuePrecision > 0
              ? scaled.toStringAsFixed(item.valuePrecision)
              : scaled.round().toString();
          return '$label${item.valueUnit}';
        },
        onChanged: (next) => controller.setDoubleSetting(settingKey, next),
      );
    }
    if (item.kind == _SettingKind.refresh) {
      return RefreshLibraryItem(
        isSyncing: controller.libraryLoading,
        onFullRescan: () async {
          await controller.refreshLibrary();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Library sync finished')),
          );
        },
        onRebuild: () => _confirmRebuildDatabase(controller),
      );
    }
    if (item.kind == _SettingKind.toggle) {
      final value = switch (settingKey) {
        'nav_bar_compact_mode' => controller.navBarCompactMode,
        _ => controller.boolSetting(settingKey, item.initialValue),
      };
      return SettingsSwitchItem(
        title: item.title,
        subtitle: item.subtitle,
        icon: item.icon,
        value: value,
        onChanged: (next) {
          if (settingKey == 'nav_bar_compact_mode') {
            controller.setNavBarCompactMode(next);
          } else {
            controller.setBoolSetting(settingKey, next);
          }
        },
      );
    }
    if (item.choices case final choices?) {
      final selected = _displaySubtitle(controller, item, settingKey);
      return SettingsChoiceItem(
        label: item.title,
        description: item.description ?? item.subtitle,
        icon: item.icon,
        options: {for (final choice in choices) choice: choice},
        selectedKey: selected,
        onSelected: (value) =>
            _applyChoiceSetting(controller, item, settingKey, value),
      );
    }
    return SettingsActionItem(
      title: item.title,
      subtitle: _displaySubtitle(controller, item, settingKey),
      icon: item.icon,
      showChevron: item.route != null || item.choices != null,
      onTap: () {
        if (item.route != null) {
          widget.onOpenScreen(item.route!);
        } else if (item.title == 'App Theme') {
          _showThemePicker(context);
        } else if (item.title == 'Palette style') {
          widget.onOpenScreen('palette');
        } else if (item.title == 'Navigation bar style') {
          widget.onOpenScreen('navbar');
        } else if (item.title == 'Default transition') {
          widget.onOpenScreen('transition');
        } else if (item.title == 'Equalizer') {
          widget.onOpenScreen('equalizer');
        } else if (item.title == 'DJ Space') {
          widget.onOpenScreen('mashup');
        } else if (item.title == 'Experimental settings') {
          widget.onOpenScreen('experimental');
        } else if (item.title == 'Run setup again') {
          controller.resetSetup();
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (item.title == 'Refresh library') {
          controller.refreshLibrary();
        } else if (item.title == 'Reset Imported Lyrics') {
          _confirmResetAllLyrics();
        } else if (item.title == 'Excluded Directories') {
          _showExcludedDirectories(controller);
        } else if (item.title == 'Create backup') {
          _createBackup(controller);
        } else if (item.title == 'Restore backup') {
          _restoreBackup(controller);
        } else if (item.title == 'API Key') {
          _editTextSetting(
            title: item.title,
            keyName: settingKey,
            obscure: true,
          );
        } else if (item.title == 'AI Model') {
          _showGeminiModelPicker();
        } else if (item.title == 'System Prompt') {
          _editTextSetting(
            title: item.title,
            keyName: settingKey,
            multiline: true,
          );
        } else if (item.title == 'Battery Optimization') {
          _openBatteryOptimizationSettings();
        } else {
          _showChoiceSetting(context, item, settingKey);
        }
      },
    );
  }

  void _applyChoiceSetting(
    AppController controller,
    _SettingItem item,
    String settingKey,
    String value,
  ) {
    if (item.title == 'App Theme') {
      controller.setThemeMode(switch (value) {
        'Light' => ThemeMode.light,
        'Dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      });
    } else if (settingKey == 'behavior_launch_tab') {
      controller.setLaunchTab(value);
    } else if (settingKey == 'library_navigation_mode') {
      controller.setLibraryCompactMode(value == 'Compact pill & grid');
      controller.setStringSetting(settingKey, value);
    } else if (settingKey == 'nav_bar_style') {
      controller.setNavBarStyle(
        value == 'Full Width'
            ? PixelNavBarStyle.fullWidth
            : PixelNavBarStyle.floating,
      );
    } else if (settingKey == 'collage_pattern') {
      controller.setStringSetting(
        settingKey,
        _collagePatternKeys[value] ?? 'cosmic_swirl',
      );
    } else if (settingKey == 'playback_keep_playing_background') {
      controller
        ..setStringSetting(settingKey, value)
        ..setBoolSetting('playback_keep_playing_in_background', value == 'On');
    } else if (settingKey == 'playback_cast_autoplay') {
      controller
        ..setStringSetting(settingKey, value)
        ..setBoolSetting('playback_disable_cast_autoplay', value == 'Disabled');
    } else if (settingKey == 'playback_crossfade_enabled') {
      controller.setBoolSetting(settingKey, value == 'Enabled');
    } else if (settingKey == 'playback_replay_gain_mode') {
      controller
        ..setStringSetting(settingKey, value)
        ..setBoolSetting('playback_replay_gain_use_album', value == 'Album');
    } else {
      controller.setStringSetting(settingKey, value);
    }
  }

  Future<void> _openBatteryOptimizationSettings() async {
    final opened = await openAppSettings();
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Battery settings are unavailable')),
    );
  }

  Future<void> _confirmResetAllLyrics() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Reset imported lyrics?'),
        content: const Text(
          'This clears lyrics imported, downloaded, or auto-assigned for every '
          'song. Embedded tags and local LRC files are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LyricsService.instance.resetAllLyrics();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Imported lyrics reset')));
  }

  Future<void> _confirmRebuildDatabase(AppController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Rebuild music database?'),
        content: const Text(
          'PixelPlay will rescan every music source and rebuild its local '
          'library index. Your audio files will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rebuild'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.refreshLibrary();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Music database rebuilt')));
  }

  String _displaySubtitle(
    AppController controller,
    _SettingItem item,
    String settingKey,
  ) {
    if (item.title == 'API Key') {
      return controller.stringSetting(settingKey, '').trim().isEmpty
          ? 'Not configured'
          : 'Configured';
    }
    if (settingKey == 'collage_pattern') {
      return _collagePatternLabels[controller.stringSetting(
            settingKey,
            'cosmic_swirl',
          )] ??
          'Cosmic Swirl';
    }
    if (settingKey == 'nav_bar_style') {
      return controller.navBarStyle == PixelNavBarStyle.fullWidth
          ? 'Full Width'
          : 'Default';
    }
    if (settingKey == 'library_navigation_mode') {
      return controller.libraryCompactMode
          ? 'Compact pill & grid'
          : 'Tab row (default)';
    }
    if (settingKey == 'playback_crossfade_enabled') {
      return controller.boolSetting(settingKey, false) ? 'Enabled' : 'Disabled';
    }
    if (item.title == 'App Theme') {
      return switch (controller.themeMode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'Follow system',
      };
    }
    return controller.stringSetting(settingKey, item.subtitle);
  }

  String _settingKey(_SettingItem item) {
    if (item.settingId != null) return item.settingId!;
    final title = item.title;
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '${widget.categoryId}_$slug';
  }

  void _showThemePicker(BuildContext context) {
    final controller = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Theme mode',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              RadioGroup<ThemeMode>(
                groupValue: controller.themeMode,
                onChanged: (value) {
                  if (value != null) controller.setThemeMode(value);
                  Navigator.pop(context);
                },
                child: Column(
                  children: [
                    for (final entry in const [
                      (
                        ThemeMode.system,
                        'Follow system',
                        Icons.brightness_auto_rounded,
                      ),
                      (ThemeMode.light, 'Light', Icons.light_mode_rounded),
                      (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
                    ])
                      RadioListTile<ThemeMode>(
                        value: entry.$1,
                        secondary: Icon(entry.$3),
                        title: Text(entry.$2),
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

  void _showChoiceSetting(
    BuildContext context,
    _SettingItem item,
    String settingKey,
  ) {
    final controller = AppScope.of(context);
    final options =
        item.choices ??
        switch (item.title) {
          'Audio quality' => const ['Original quality', 'High', 'Data saver'],
          'Launch tab' => const ['Home', 'Search', 'Library'],
          'Provider' => const ['Gemini', 'OpenAI compatible'],
          'Preset' => const ['Flat', 'Rock', 'Pop', 'Jazz', 'Classical'],
          'Bass boost' => const ['0%', '25%', '50%', '75%', '100%'],
          'Artist separators' => const [',', ';', '/', '&', 'feat.'],
          'Audio codecs' => const ['AAC', 'FLAC', 'MP3', 'Opus', 'Vorbis'],
          _ => <String>[item.subtitle],
        };
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  item.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              RadioGroup<String>(
                groupValue: settingKey == 'collage_pattern'
                    ? _collagePatternLabels[controller.stringSetting(
                            settingKey,
                            'cosmic_swirl',
                          )] ??
                          'Cosmic Swirl'
                    : _displaySubtitle(controller, item, settingKey),
                onChanged: (value) {
                  if (value != null) {
                    if (settingKey == 'behavior_launch_tab') {
                      controller.setLaunchTab(value);
                    } else if (settingKey == 'library_navigation_mode') {
                      controller.setLibraryCompactMode(
                        value == 'Compact pill & grid',
                      );
                      controller.setStringSetting(settingKey, value);
                    } else if (settingKey == 'nav_bar_style') {
                      controller.setNavBarStyle(
                        value == 'Full Width'
                            ? PixelNavBarStyle.fullWidth
                            : PixelNavBarStyle.floating,
                      );
                    } else if (settingKey == 'collage_pattern') {
                      controller.setStringSetting(
                        settingKey,
                        _collagePatternKeys[value] ?? 'cosmic_swirl',
                      );
                    } else {
                      controller.setStringSetting(settingKey, value);
                    }
                  }
                  Navigator.pop(context);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in options)
                      RadioListTile<String>(value: option, title: Text(option)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _collagePatternLabels = <String, String>{
    'cosmic_swirl': 'Cosmic Swirl',
    'honeycomb_groove': 'Honeycomb Groove',
    'vinyl_stack': 'Vinyl Stack',
    'pixel_mosaic': 'Pixel Mosaic',
    'stardust_scatter': 'Stardust Scatter',
  };

  static const _collagePatternKeys = <String, String>{
    'Cosmic Swirl': 'cosmic_swirl',
    'Honeycomb Groove': 'honeycomb_groove',
    'Vinyl Stack': 'vinyl_stack',
    'Pixel Mosaic': 'pixel_mosaic',
    'Stardust Scatter': 'stardust_scatter',
  };

  Future<void> _showExcludedDirectories(AppController controller) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final blocked = controller.stringListSetting(
              'library_blocked_directories',
              const [],
            );
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                      child: Text(
                        'Excluded Directories',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Text(
                        'Folders here will be skipped when scanning your '
                        'library.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: blocked.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.folder_off_outlined, size: 52),
                                  SizedBox(height: 12),
                                  Text('No excluded directories'),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: blocked.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 2),
                              itemBuilder: (context, index) => Material(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(10),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.folder_off_outlined,
                                  ),
                                  title: Text(
                                    blocked[index].split(RegExp(r'[/\\]')).last,
                                  ),
                                  subtitle: Text(
                                    blocked[index],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    onPressed: () {
                                      controller.setStringListSetting(
                                        'library_blocked_directories',
                                        blocked.where(
                                          (path) => path != blocked[index],
                                        ),
                                      );
                                      setSheetState(() {});
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                    tooltip: 'Remove exclusion',
                                  ),
                                ),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final directory = await FilePicker.getDirectoryPath(
                              dialogTitle: 'Exclude a music directory',
                            );
                            if (directory == null ||
                                blocked.contains(directory)) {
                              return;
                            }
                            controller.setStringListSetting(
                              'library_blocked_directories',
                              [...blocked, directory],
                            );
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.create_new_folder_outlined),
                          label: const Text('Add Directory'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    await controller.refreshLibrary();
  }

  Future<void> _createBackup(AppController controller) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Create PixelPlay backup',
      fileName: 'pixelplay-backup.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return;
    await File(path).writeAsString(controller.createBackupJson(), flush: true);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Backup created')));
  }

  Future<void> _restoreBackup(AppController controller) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Restore PixelPlay backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      await controller.restoreBackupJson(await File(path).readAsString());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup restored')));
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _editTextSetting({
    required String title,
    required String keyName,
    bool obscure = false,
    bool multiline = false,
  }) async {
    final controller = AppScope.of(context);
    final text = TextEditingController(
      text: controller.stringSetting(keyName, ''),
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: text,
          obscureText: obscure,
          minLines: multiline ? 6 : 1,
          maxLines: obscure
              ? 1
              : multiline
              ? 12
              : 1,
          decoration: InputDecoration(labelText: title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              controller.setStringSetting(keyName, text.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    text.dispose();
  }

  Future<void> _showGeminiModelPicker() async {
    final controller = AppScope.of(context);
    final apiKey = controller.stringSetting('gemini_api_key', '').trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configure your Gemini API key first')),
      );
      return;
    }
    final selected = controller.stringSetting(
      'gemini_model',
      GeminiAiClient.defaultModel,
    );
    final models = const GeminiAiClient().listModels(apiKey);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: FutureBuilder<List<String>>(
            future: models,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 18),
                      Text('Loading Gemini models…'),
                    ],
                  ),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
              final values = snapshot.data ?? GeminiAiClient.defaultModels;
              return Column(
                children: [
                  ListTile(
                    title: Text(
                      'Gemini model',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    subtitle: const Text(
                      'Models available to the configured API key',
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: RadioGroup<String>(
                      groupValue: selected,
                      onChanged: (value) {
                        if (value == null) return;
                        controller.setStringSetting('gemini_model', value);
                        Navigator.pop(context);
                      },
                      child: ListView.builder(
                        itemCount: values.length,
                        itemBuilder: (context, index) {
                          final model = values[index];
                          return RadioListTile<String>(
                            value: model,
                            title: Text(model),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<_SettingSection> _sectionsFor(String id) => switch (id) {
    'library' => const [
      _SettingSection('Library Structure', [
        _SettingItem.action(
          'Excluded Directories',
          'Folders here will be skipped when scanning your library.',
          Icons.folder_outlined,
        ),
        _SettingItem.action(
          'Artists',
          'Multi-artist parsing and organization options.',
          Icons.person_outline_rounded,
          route: 'artist-settings',
        ),
      ]),
      _SettingSection('Filtering', [
        _SettingItem.slider(
          'Minimum Song Duration',
          settingId: 'library_min_song_duration_ms',
          initialValue: 0,
          min: 0,
          max: 120000,
          divisions: 24,
          valueDivisor: 1000,
          valueUnit: 's',
        ),
        _SettingItem.slider(
          'Minimum Tracks per Album',
          settingId: 'library_min_tracks_per_album',
          initialValue: 1,
          min: 1,
          max: 5,
          divisions: 4,
        ),
        _SettingItem.slider(
          'Album Art Cache Limit',
          settingId: 'library_album_art_cache_limit_mb',
          initialValue: 250,
          min: 50,
          max: 1500,
          divisions: 29,
          valueUnit: ' MB',
        ),
      ]),
      _SettingSection('Sync and Scanning', [
        _SettingItem.refresh(),
        _SettingItem.toggle(
          'Auto-scan .lrc files',
          'Automatically scan and assign .lrc files in the same folder during '
              'library sync.',
          Icons.folder_outlined,
          true,
          settingId: 'auto_scan_lrc_files',
        ),
      ]),
      _SettingSection('Lyrics Management', [
        _SettingItem.action(
          'Lyrics Source Priority',
          'Embedded First',
          Icons.lyrics_outlined,
          settingId: 'library_lyrics_source_priority',
          choices: ['Embedded First', 'Online First', 'Local (.lrc) First'],
          description: 'Choose which source to try first when fetching lyrics.',
        ),
        _SettingItem.action(
          'Reset Imported Lyrics',
          'Remove all imported lyrics from the database.',
          Icons.clear_all_rounded,
        ),
      ]),
    ],
    'appearance' => const [
      _SettingSection('Global Theme', [
        _SettingItem.action(
          'App Language',
          'System default',
          Icons.language_outlined,
          choices: ['System default', 'English'],
          description: 'Choose the language used across the app interface.',
        ),
        _SettingItem.action(
          'App Theme',
          'Follow system',
          Icons.light_mode_outlined,
          choices: ['Follow system', 'Light', 'Dark'],
          description:
              'Switch between light, dark, or follow system appearance.',
        ),
        _SettingItem.toggle(
          'Use Smooth Corners',
          'Use complex shaped corners effectively improving aesthetics but '
              'may affect performance on low-end devices',
          Icons.rounded_corner_rounded,
          true,
          settingId: 'appearance_smooth_corners',
        ),
        _SettingItem.toggle(
          'Disable Blur Effects',
          'Turn off blur effects across the app to save battery and resources.',
          Icons.blur_off_rounded,
          false,
          settingId: 'disable_blur_all_over',
        ),
        _SettingItem.toggle(
          'Show Scrollbar',
          'Display lateral scrollbar on music lists for quick scrolling',
          Icons.unfold_more_rounded,
          true,
          settingId: 'show_scrollbar',
        ),
      ]),
      _SettingSection('Now Playing', [
        _SettingItem.action(
          'Player Theme',
          'Album Art',
          Icons.play_circle_outline_rounded,
          settingId: 'appearance_player_palette',
          choices: ['Album Art', 'System Dynamic'],
          description: 'Choose the appearance for the floating player.',
        ),
        _SettingItem.toggle(
          'Show player file info',
          'Show codec, bitrate, and sample rate in the player progress section.',
          Icons.attach_file_rounded,
          true,
          settingId: 'appearance_show_player_file_info',
        ),
        _SettingItem.action(
          'Album Art Palette Style',
          'Open live preview and choose style.',
          Icons.style_outlined,
          route: 'palette',
        ),
        _SettingItem.action(
          'Carousel Style',
          'No Peek',
          Icons.view_carousel_outlined,
          settingId: 'carousel_style',
          choices: ['No Peek', 'One Peek'],
          description: 'Choose the appearance for the album carousel.',
        ),
      ]),
      _SettingSection('Home Collage', [
        _SettingItem.action(
          'Collage Pattern',
          'Cosmic Swirl',
          Icons.view_column_rounded,
          settingId: 'collage_pattern',
          choices: [
            'Cosmic Swirl',
            'Honeycomb Groove',
            'Vinyl Stack',
            'Pixel Mosaic',
            'Stardust Scatter',
          ],
          description: 'Choose the shape arrangement for the Your Mix collage.',
        ),
        _SettingItem.toggle(
          'Auto-Rotate Patterns',
          'Cycle through collage patterns each time you visit Home.',
          Icons.shuffle_rounded,
          false,
          settingId: 'collage_auto_rotate',
        ),
      ]),
      _SettingSection('Navigation Bar', [
        _SettingItem.action(
          'NavBar Style',
          'Default',
          Icons.style_outlined,
          settingId: 'nav_bar_style',
          choices: ['Default', 'Full Width'],
          description: 'Choose the appearance for the navigation bar.',
        ),
        _SettingItem.toggle(
          'Compact mode',
          'Show only icons and reduce the navbar height.',
          Icons.view_week_outlined,
          false,
          settingId: 'nav_bar_compact_mode',
        ),
        _SettingItem.action(
          'NavBar Corner Radius',
          'Adjust the corner radius of the navigation bar.',
          Icons.rounded_corner_rounded,
          route: 'navbar',
        ),
      ]),
      _SettingSection('Lyrics Screen', [
        _SettingItem.toggle(
          'Immersive Lyrics',
          'Auto-hide controls and enlarge text.',
          Icons.lyrics_rounded,
          true,
          settingId: 'immersive_lyrics',
        ),
        _SettingItem.action(
          'Auto-hide Delay',
          '5s',
          Icons.timer_rounded,
          settingId: 'immersive_lyrics_timeout',
          choices: ['3s', '4s', '5s', '6s'],
          description: 'Time before controls hide.',
        ),
      ]),
      _SettingSection('App Navigation', [
        _SettingItem.action(
          'Default Tab',
          'Home',
          Icons.tab_rounded,
          settingId: 'behavior_launch_tab',
          choices: ['Home', 'Search', 'Library'],
          description: 'Choose the Default launch tab.',
        ),
        _SettingItem.action(
          'Library Navigation',
          'Tab row (default)',
          Icons.library_music_outlined,
          settingId: 'library_navigation_mode',
          choices: ['Tab row (default)', 'Compact pill & grid'],
          description: 'Choose how to move between Library tabs.',
        ),
      ]),
    ],
    'playback' => const [
      _SettingSection('Background Playback', [
        _SettingItem.action(
          'Keep playing after closing',
          'On',
          Icons.music_note_rounded,
          settingId: 'playback_keep_playing_background',
          choices: ['On', 'Off'],
          description:
              'If off, removing the app from recents will stop playback.',
        ),
        _SettingItem.action(
          'Battery Optimization',
          'Disable battery optimization to prevent playback interruptions.',
          Icons.all_inclusive_rounded,
        ),
      ]),
      _SettingSection('Volume Normalization (ReplayGain)', [
        _SettingItem.toggle(
          'Enable ReplayGain',
          'Normalize volume levels using ReplayGain metadata from audio files.',
          Icons.volume_down_outlined,
          false,
          settingId: 'playback_replay_gain_enabled',
        ),
        _SettingItem.action(
          'Gain Mode',
          'Track',
          Icons.volume_down_outlined,
          settingId: 'playback_replay_gain_mode',
          choices: ['Track', 'Album'],
          description:
              'Track: normalize each song. Album: normalize per album.',
        ),
      ]),
      _SettingSection('Cast', [
        _SettingItem.action(
          'Auto-play on cast connect/disconnect',
          'Enabled',
          Icons.cast_rounded,
          settingId: 'playback_cast_autoplay',
          choices: ['Enabled', 'Disabled'],
          description:
              'Start playing immediately after switching cast connections.',
        ),
      ]),
      _SettingSection('Volume', [
        _SettingItem.toggle(
          'Pause when volume reaches zero',
          'Automatically pause playback when the volume is set to 0',
          Icons.volume_down_outlined,
          false,
          settingId: 'playback_pause_on_volume_zero',
        ),
      ]),
      _SettingSection('Headphones', [
        _SettingItem.toggle(
          'Resume when headphones reconnect',
          'If playback paused because headphones were removed, resume '
              'automatically when they connect again.',
          Icons.headphones_rounded,
          false,
          settingId: 'playback_resume_on_headset_reconnect',
        ),
      ]),
      _SettingSection('Queue and Transitions', [
        _SettingItem.action(
          'Crossfade',
          'Disabled',
          Icons.align_horizontal_left_rounded,
          settingId: 'playback_crossfade_enabled',
          choices: ['Enabled', 'Disabled'],
          description: 'Enable smooth transition between songs.',
        ),
        _SettingItem.slider(
          'Crossfade Duration',
          settingId: 'playback_crossfade_duration_ms',
          initialValue: 5000,
          min: 1000,
          max: 12000,
          divisions: 11,
          valueDivisor: 1000,
          valueUnit: 's',
        ),
        _SettingItem.toggle(
          'Hi-Fi Mode',
          'Float 32-bit audio output. Disable if playback stutters on your '
              'device.',
          Icons.high_quality_outlined,
          false,
          settingId: 'playback_hifi_mode_enabled',
        ),
        _SettingItem.toggle(
          'Persistent Shuffle',
          'Remember shuffle setting even after closing the app.',
          Icons.shuffle_rounded,
          false,
          settingId: 'playback_persistent_shuffle',
        ),
        _SettingItem.toggle(
          'Show queue history',
          'Show previously played songs in the queue.',
          Icons.queue_music_rounded,
          true,
          settingId: 'playback_show_queue_history',
        ),
      ]),
    ],
    'behavior' => const [
      _SettingSection('Folders', [
        _SettingItem.toggle(
          'Back gesture controls folders',
          'In Folders tab, system back navigates folder stack before leaving '
              'Library.',
          Icons.touch_app_rounded,
          true,
          settingId: 'folder_back_gesture_navigation',
        ),
      ]),
      _SettingSection('Player Gestures', [
        _SettingItem.toggle(
          'Tap background closes player',
          'Tap the blurred background to close the player sheet.',
          Icons.touch_app_rounded,
          false,
          settingId: 'tap_background_closes_player',
        ),
      ]),
      _SettingSection('Haptics', [
        _SettingItem.toggle(
          'Haptic feedback',
          'Enable vibration feedback across the app.',
          Icons.touch_app_rounded,
          true,
          settingId: 'haptics_enabled',
        ),
      ]),
    ],
    'ai' => const [
      _SettingSection('AI Provider', [
        _SettingItem.action(
          'Provider',
          'Google Gemini',
          Icons.science_rounded,
          settingId: 'ai_provider',
          choices: [
            'Google Gemini',
            'DeepSeek',
            'Groq',
            'Mistral',
            'NVIDIA NIM',
            'Kimi (Moonshot)',
            'Zhipu GLM',
            'OpenAI',
            'OpenRouter',
            'Ollama',
            'Custom Provider',
          ],
          description: 'Choose your AI provider',
        ),
        _SettingItem.toggle(
          'Safe Token Mode',
          'ON — Fast & cheap. Sends minimal data (~1K tokens) to AI.',
          Icons.monitor_heart_rounded,
          true,
          settingId: 'ai_safe_token_limit',
        ),
      ]),
      _SettingSection('Credentials', [
        _SettingItem.action(
          'API Key',
          'Not configured',
          Icons.key_rounded,
          settingId: 'gemini_api_key',
        ),
      ]),
      _SettingSection('Model Selection', [
        _SettingItem.action(
          'AI Model',
          GeminiAiClient.defaultModel,
          Icons.science_rounded,
          settingId: 'gemini_model',
        ),
      ]),
      _SettingSection('Prompt Behavior', [
        _SettingItem.action(
          'System Prompt',
          'Customize how the AI behaves.',
          Icons.psychology_alt_rounded,
          settingId: 'gemini_system_prompt',
        ),
      ]),
      _SettingSection('Generation Parameters', [
        _SettingItem.slider(
          'Temperature',
          settingId: 'ai_temperature',
          initialValue: 1,
          min: 0,
          max: 2,
          divisions: 20,
          valuePrecision: 2,
        ),
        _SettingItem.slider(
          'Top P',
          settingId: 'ai_top_p',
          initialValue: 0.95,
          min: 0,
          max: 1,
          divisions: 20,
          valuePrecision: 2,
        ),
        _SettingItem.slider(
          'Top K',
          settingId: 'ai_top_k',
          initialValue: 40,
          min: 1,
          max: 100,
          divisions: 99,
        ),
        _SettingItem.slider(
          'Max Output Tokens',
          settingId: 'ai_max_tokens',
          initialValue: 4096,
          min: 128,
          max: 8192,
          divisions: 64,
        ),
        _SettingItem.slider(
          'Presence Penalty',
          settingId: 'ai_presence_penalty',
          initialValue: 0,
          min: -2,
          max: 2,
          divisions: 40,
          valuePrecision: 1,
        ),
        _SettingItem.slider(
          'Frequency Penalty',
          settingId: 'ai_frequency_penalty',
          initialValue: 0,
          min: -2,
          max: 2,
          divisions: 40,
          valuePrecision: 1,
        ),
      ]),
      _SettingSection('Song Data Configuration', [
        _SettingItem.slider(
          'Sample Size',
          settingId: 'ai_sample_size',
          initialValue: 30,
          min: 10,
          max: 120,
          divisions: 11,
          valueUnit: ' songs',
        ),
        _SettingItem.action(
          'Digest Detail',
          'Concise (faster)',
          Icons.monitor_heart_rounded,
          settingId: 'ai_digest_mode',
          choices: ['Concise (faster)', 'Full (better quality)'],
          description: 'Controls how much listening history data is included',
        ),
        _SettingItem.toggle(
          'Extended Song Fields',
          'Include album, year, and genre info in song data sent to AI',
          Icons.music_note_rounded,
          true,
          settingId: 'ai_include_extended_fields',
        ),
      ]),
      _SettingSection('AI Usage Report', [
        _SettingItem.action(
          'Total Consumption',
          'No AI requests recorded yet.',
          Icons.monitor_heart_rounded,
        ),
      ]),
    ],
    'backup_restore' => const [
      _SettingSection('PixelPlay data', [
        _SettingItem.action(
          'Create backup',
          'Export playlists, settings and history',
          Icons.backup_rounded,
        ),
        _SettingItem.action(
          'Restore backup',
          'Choose a PixelPlay backup file',
          Icons.settings_backup_restore_rounded,
        ),
      ]),
    ],
    'developer' => const [
      _SettingSection('Experimental', [
        _SettingItem.toggle(
          'Experimental features',
          'Enable unfinished PixelPlay functionality',
          Icons.science_rounded,
          false,
        ),
        _SettingItem.toggle(
          'Performance overlay',
          'Show frame and rebuild diagnostics',
          Icons.monitor_heart_rounded,
          false,
        ),
        _SettingItem.action(
          'Experimental settings',
          'Player composition, lyrics and gesture prototypes',
          Icons.science_rounded,
        ),
        _SettingItem.action(
          'Run setup again',
          'Reset the onboarding gate',
          Icons.restart_alt_rounded,
        ),
        _SettingItem.action(
          'DJ Space',
          'Mix two songs with dual decks',
          Icons.album_rounded,
        ),
      ]),
    ],
    'equalizer' => const [
      _SettingSection('Equalizer', [
        _SettingItem.toggle(
          'Enable equalizer',
          'Apply audio effects to playback',
          Icons.graphic_eq_rounded,
          false,
        ),
        _SettingItem.action('Preset', 'Flat', Icons.tune_rounded),
        _SettingItem.action('Bass boost', '0%', Icons.surround_sound_rounded),
      ]),
    ],
    _ => const [
      _SettingSection('Device', [
        _SettingItem.action(
          'Audio codecs',
          'AAC, FLAC, MP3, Opus, Vorbis',
          Icons.audio_file_rounded,
        ),
        _SettingItem.action(
          'Android version',
          'Read from this device',
          Icons.android_rounded,
        ),
        _SettingItem.action(
          'Storage access',
          'Scoped media access',
          Icons.storage_rounded,
        ),
      ]),
    ],
  };
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1) const SizedBox(height: 2),
        ],
      ],
    );
  }
}

enum _SettingKind { toggle, action, slider, refresh }

class _SettingSection {
  const _SettingSection(this.title, this.items);
  final String title;
  final List<_SettingItem> items;
}

class _SettingItem {
  const _SettingItem.toggle(
    this.title,
    this.subtitle,
    this.icon,
    this.initialValue, {
    // ignore: unused_element_parameter
    this.settingId,
  }) : kind = _SettingKind.toggle,
       choices = null,
       route = null,
       description = null,
       initialDouble = 0,
       min = 0,
       max = 0,
       divisions = 0,
       valueDivisor = 1,
       valueUnit = '',
       valuePrecision = 0;

  const _SettingItem.action(
    this.title,
    this.subtitle,
    this.icon, {
    // ignore: unused_element_parameter
    this.settingId,
    // ignore: unused_element_parameter
    this.choices,
    // ignore: unused_element_parameter
    this.route,
    this.description,
  }) : kind = _SettingKind.action,
       initialValue = false,
       initialDouble = 0,
       min = 0,
       max = 0,
       divisions = 0,
       valueDivisor = 1,
       valueUnit = '',
       valuePrecision = 0;

  const _SettingItem.slider(
    this.title, {
    required this.settingId,
    required double initialValue,
    required this.min,
    required this.max,
    required this.divisions,
    this.valueDivisor = 1,
    this.valueUnit = '',
    this.valuePrecision = 0,
  }) : subtitle = '',
       icon = Icons.tune_rounded,
       kind = _SettingKind.slider,
       initialValue = false,
       initialDouble = initialValue,
       choices = null,
       route = null,
       description = null;

  const _SettingItem.refresh()
    : title = 'Refresh Library',
      subtitle = 'Scan entire library for new and modified files.',
      icon = Icons.sync_rounded,
      kind = _SettingKind.refresh,
      initialValue = false,
      initialDouble = 0,
      settingId = null,
      choices = null,
      route = null,
      description = null,
      min = 0,
      max = 0,
      divisions = 0,
      valueDivisor = 1,
      valueUnit = '',
      valuePrecision = 0;

  final String title;
  final String subtitle;
  final IconData icon;
  final _SettingKind kind;
  final bool initialValue;
  final double initialDouble;
  final String? settingId;
  final List<String>? choices;
  final String? route;
  final String? description;
  final double min;
  final double max;
  final int divisions;
  final double valueDivisor;
  final String valueUnit;
  final int valuePrecision;
}
