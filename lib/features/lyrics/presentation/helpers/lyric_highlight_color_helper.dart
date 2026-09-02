import 'package:flutter/material.dart';

import '../../../../app/config/app_config_state.dart';
import '../../../../app/config/app_lyric_highlight_color.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';

Color resolveLyricHighlightColor(AppConfigState config, {Color? autoColor}) {
  return resolveLyricHighlightColorValues(
    mode: config.lyricHighlightMode,
    preset: config.lyricHighlightPreset,
    customColorValue: config.lyricHighlightCustomColor,
    autoColor: autoColor,
  );
}

Color resolveLyricHighlightColorValues({
  required AppLyricHighlightMode mode,
  required AppLyricHighlightColor preset,
  required int? customColorValue,
  Color? autoColor,
}) {
  return switch (mode) {
    AppLyricHighlightMode.auto => autoColor ?? AppLyricHighlightColor.sky.color,
    AppLyricHighlightMode.custom =>
      customColorValue == null
          ? AppLyricHighlightColor.sky.color
          : Color(customColorValue),
    AppLyricHighlightMode.preset => preset.color,
  };
}
