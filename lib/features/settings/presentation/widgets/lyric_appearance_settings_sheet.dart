import 'package:flutter/material.dart';

import '../../../../app/config/app_config_state.dart';
import '../../../../app/config/app_lyric_font_preset.dart';
import '../../../../app/config/app_lyric_highlight_color.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../pages/settings_item_presentation_registry.dart';
import 'settings_single_choice_sheet.dart';

Future<void> showLyricFontPresetSettingsSheet({
  required BuildContext context,
  required AppConfigState config,
  required ValueChanged<AppLyricFontPreset> onSelected,
  bool playerStyled = false,
}) => showSettingsSingleChoiceSheet<AppLyricFontPreset>(
  context: context,
  title: AppI18n.t(config, 'settings.lyric_font_preset'),
  currentValue: config.lyricFontPreset,
  playerStyled: playerStyled,
  options: [
    for (final preset in AppLyricFontPreset.values)
      SettingsChoiceOption(
        value: preset,
        title: settingsLyricFontPresetLabel(preset, config),
        cupertinoTitleStyle: TextStyle(
          fontSize: _previewFontSize(preset),
          fontWeight: FontWeight.w500,
        ),
      ),
  ],
  onSelected: onSelected,
);

/// Preview for lyric highlight color choices.
class LyricSettingsPreview extends StatelessWidget {
  const LyricSettingsPreview({required this.config, super.key});

  final AppConfigState config;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Container(
      key: const ValueKey('settings-lyric-preview'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1e),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            AppI18n.t(config, 'settings.lyric.preview'),
            style: const TextStyle(color: Color(0xffaeaeb2), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            AppI18n.t(config, 'settings.lyric.preview_line'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: lyricSettingsHighlightPreviewColor(config),
              fontSize: _previewFontSize(config.lyricFontPreset),
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );
}

Color lyricSettingsHighlightPreviewColor(AppConfigState config) =>
    switch (config.lyricHighlightMode) {
      AppLyricHighlightMode.custom =>
        config.lyricHighlightCustomColor == null
            ? AppLyricHighlightColor.sky.color
            : Color(config.lyricHighlightCustomColor!),
      AppLyricHighlightMode.auto => AppLyricHighlightColor.sky.color,
      AppLyricHighlightMode.preset => config.lyricHighlightPreset.color,
    };

double _previewFontSize(AppLyricFontPreset preset) => switch (preset) {
  AppLyricFontPreset.small => 20,
  AppLyricFontPreset.medium => 24,
  AppLyricFontPreset.large => 28,
};
