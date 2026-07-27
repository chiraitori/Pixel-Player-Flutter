import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import 'delimiter_config_screen.dart';

class WordDelimiterConfigScreen extends StatelessWidget {
  const WordDelimiterConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return DelimiterEditorScreen(
      title: 'Word delimiters',
      subtitle: 'Match artist join words without caring about letter case.',
      valueLabel: 'Current word delimiters',
      inputLabel: 'Add a word delimiter',
      values: controller.stringListSetting(
        'artist_word_delimiters',
        AppController.defaultArtistWordDelimiters,
      ),
      defaults: AppController.defaultArtistWordDelimiters,
      minimumCount: 0,
      duplicateCaseInsensitive: true,
      onSave: (values) {
        controller.setStringListSetting('artist_word_delimiters', values);
        controller.setBoolSetting('artist_rescan_required', true);
      },
    );
  }
}
