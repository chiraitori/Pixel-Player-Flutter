import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import '../../shared/widgets/collapsible_common_top_bar.dart';

class ExperimentalSettingsScreen extends StatefulWidget {
  const ExperimentalSettingsScreen({super.key});

  @override
  State<ExperimentalSettingsScreen> createState() =>
      _ExperimentalSettingsScreenState();
}

class _ExperimentalSettingsScreenState
    extends State<ExperimentalSettingsScreen> {
  static const _toggleSettings = <String, ({String key, bool fallback})>{
    'Animated lyrics': (key: 'experimental_animated_lyrics', fallback: false),
    'Lyrics background blur': (key: 'experimental_lyrics_blur', fallback: true),
    'Immersive lyrics': (key: 'immersive_lyrics', fallback: false),
    'Delay player content': (
      key: 'experimental_delay_player_content',
      fallback: false,
    ),
    'Album carousel': (
      key: 'experimental_delay_album_carousel',
      fallback: true,
    ),
    'Song metadata': (key: 'experimental_delay_song_metadata', fallback: true),
    'Progress bar': (key: 'experimental_delay_progress_bar', fallback: true),
    'Playback controls': (
      key: 'experimental_delay_playback_controls',
      fallback: true,
    ),
    'Use placeholders': (key: 'experimental_use_placeholders', fallback: true),
    'Apply player state on close': (
      key: 'experimental_apply_player_state_on_close',
      fallback: false,
    ),
    'Predictive back': (key: 'experimental_predictive_back', fallback: true),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CollapsibleCommonTopBar(
            title: 'Experimental',
            onBack: () => Navigator.maybePop(context),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
            sliver: SliverList.list(
              children: [
                _warning(context),
                _header(context, 'Player UI tweaks'),
                _group([
                  _toggle(
                    'Animated lyrics',
                    'Animate synced lyric lines and transitions',
                  ),
                  _toggle(
                    'Lyrics background blur',
                    'Apply depth-of-field blur to inactive lyric lines',
                  ),
                  _toggle(
                    'Immersive lyrics',
                    'Auto-hide controls and enlarge synced lyrics',
                  ),
                  _slider(
                    'Lyrics blur strength',
                    AppScope.of(
                      context,
                    ).doubleSetting('experimental_lyrics_blur_strength', .25),
                    (value) => AppScope.of(context).setDoubleSetting(
                      'experimental_lyrics_blur_strength',
                      value,
                    ),
                  ),
                ]),
                _header(context, 'Deferred player composition'),
                _group([
                  _toggle(
                    'Delay player content',
                    'Load full-player content in stages',
                  ),
                  _toggle(
                    'Album carousel',
                    'Delay the neighboring album carousel',
                  ),
                  _toggle(
                    'Song metadata',
                    'Delay title and artist information',
                  ),
                  _toggle('Progress bar', 'Delay the seek control'),
                  _toggle('Playback controls', 'Delay transport controls'),
                  _toggle(
                    'Use placeholders',
                    'Keep stable placeholders while loading',
                  ),
                ]),
                _header(context, 'Gesture trigger'),
                _group([
                  _slider(
                    'Expand threshold',
                    AppScope.of(
                      context,
                    ).doubleSetting('experimental_expand_threshold', .42),
                    (value) => AppScope.of(
                      context,
                    ).setDoubleSetting('experimental_expand_threshold', value),
                  ),
                  _toggle(
                    'Apply player state on close',
                    'Keep the expanded state until close',
                  ),
                  _toggle(
                    'Predictive back',
                    'Animate the player with the system back gesture',
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _warning(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.science_rounded, color: colors.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'These options mirror unfinished Kotlin experiments and may change behavior between builds.',
                style: TextStyle(color: colors.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _group(List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Column(children: children),
      ),
    );
  }

  Widget _toggle(String title, String subtitle) {
    final controller = AppScope.of(context);
    final setting = _toggleSettings[title]!;
    return SwitchListTile(
      value: controller.boolSetting(setting.key, setting.fallback),
      onChanged: (value) => controller.setBoolSetting(setting.key, value),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  Widget _slider(String title, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              Text('${(value * 100).round()}%'),
            ],
          ),
          Slider(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
