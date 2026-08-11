import 'package:flutter/material.dart';

import '../app_player_scene_palette.dart';

const PlayerScenePalette classicPlayerScenePaletteFallback = PlayerScenePalette(
  surface: Color(0xFF1E2E29),
  surfaceDeep: Color(0xFF09100D),
  surfaceRaised: Color(0xFF2B4038),
  edge: Color(0xFFA7E2C5),
  accent: Color(0xFFD8C38F),
  foreground: Color(0xFFF7FAF8),
  secondaryForeground: Color(0xC7D9E4DE),
  onAccent: Color(0xFF13201B),
);

/// 将共享背景解析出的封面色映射为经典播放器场景色。
PlayerScenePalette classicPlayerScenePaletteFromBackdrop(List<Color> colors) {
  if (colors.isEmpty) return classicPlayerScenePaletteFallback;

  final dominant = colors.first;
  final highlight = colors.length > 1 ? colors[1] : dominant;
  final anchor = colors.length > 3 ? colors[3] : colors.last;
  final edge = _classicSignalColor(
    dominant,
    saturationRange: const (0.28, 0.60),
    lightness: 0.72,
  );
  final accent = _classicSignalColor(
    highlight,
    saturationRange: const (0.38, 0.68),
    lightness: 0.68,
  );
  final surface = Color.lerp(const Color(0xFF18231F), dominant, 0.32)!;
  final surfaceDeep = Color.lerp(const Color(0xFF060A08), anchor, 0.16)!;
  final surfaceRaised = Color.lerp(const Color(0xFF293932), dominant, 0.22)!;
  final foreground = Color.lerp(const Color(0xFFF7FAF8), edge, 0.05)!;
  final secondaryForeground = Color.lerp(
    const Color(0xFFD9E4DE),
    edge,
    0.12,
  )!.withValues(alpha: 0.78);

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
