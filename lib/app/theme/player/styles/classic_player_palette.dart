import 'package:flutter/material.dart';

import '../app_player_scene_palette.dart';

const PlayerScenePalette classicPlayerScenePaletteFallback = PlayerScenePalette(
  surface: Color(0xFF3B3B44),
  surfaceDeep: Color(0xFF1C1C24),
  surfaceRaised: Color(0xFF555560),
  edge: Color(0xFFD4D4DE),
  accent: Color(0xFFD7D4E8),
  foreground: Color(0xFFF5F5F8),
  secondaryForeground: Color(0xFFC1C1CC),
  onAccent: Color(0xFF23232B),
);

/// 将共享背景解析出的封面色映射为经典播放器场景色。
PlayerScenePalette classicPlayerScenePaletteFromBackdrop(List<Color> colors) {
  if (colors.isEmpty) return classicPlayerScenePaletteFallback;

  final dominant = colors.first;
  final highlight = colors.length > 1 ? colors[1] : dominant;
  final anchor = colors.length > 3 ? colors[3] : colors.last;
  final edge = _classicSignalColor(
    dominant,
    saturationRange: const (0.0, 0.24),
    lightness: 0.82,
  );
  final accent = _classicSignalColor(
    highlight,
    saturationRange: const (0.0, 0.36),
    lightness: 0.78,
  );
  // Keep every surface in the artwork's hue family, including neutral covers.
  final surface = _classicSignalColor(
    dominant,
    saturationRange: const (0.0, 0.22),
    lightness: 0.23,
  );
  final surfaceDeep = _classicSignalColor(
    anchor,
    saturationRange: const (0.0, 0.20),
    lightness: 0.12,
  );
  final surfaceRaised = _classicSignalColor(
    dominant,
    saturationRange: const (0.0, 0.20),
    lightness: 0.32,
  );
  final foreground = Color.lerp(const Color(0xFFF6F6F8), edge, 0.06)!;
  final secondaryForeground = _classicSignalColor(
    dominant,
    saturationRange: const (0.0, 0.12),
    lightness: 0.78,
  );
  return PlayerScenePalette(
    surface: surface,
    surfaceDeep: surfaceDeep,
    surfaceRaised: surfaceRaised,
    edge: edge,
    accent: accent,
    foreground: foreground,
    secondaryForeground: secondaryForeground,
    onAccent: accent.computeLuminance() > 0.42 ? surfaceDeep : foreground,
  );
}

Color _classicSignalColor(
  Color source, {
  required (double, double) saturationRange,
  required double lightness,
}) {
  final hsl = HSLColor.fromColor(source);
  return hsl
      .withSaturation(
        hsl.saturation.clamp(saturationRange.$1, saturationRange.$2),
      )
      .withLightness(lightness)
      .toColor();
}
