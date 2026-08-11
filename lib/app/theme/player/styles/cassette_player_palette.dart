import 'package:flutter/material.dart';

import '../app_player_scene_palette.dart';

/// 磁带舞台专用映射，公共播放器控件只消费 [PlayerScenePalette]。
@immutable
class CassettePlayerPalette extends PlayerScenePalette {
  const CassettePlayerPalette({
    required super.surface,
    required super.surfaceDeep,
    required super.surfaceRaised,
    required super.edge,
    required super.accent,
    required super.foreground,
    required super.secondaryForeground,
    required super.onAccent,
  });

  static const CassettePlayerPalette fallback = CassettePlayerPalette(
    surface: Color(0xFF263234),
    surfaceDeep: Color(0xFF0B1112),
    surfaceRaised: Color(0xFF344042),
    edge: Color(0xFF70E1D1),
    accent: Color(0xFFFF7368),
    foreground: Color(0xFFF4F0E7),
    secondaryForeground: Color(0xBFD6E1DE),
    onAccent: Color(0xFF111718),
  );

  factory CassettePlayerPalette.fromBackdrop(List<Color> colors) {
    if (colors.isEmpty) return fallback;

    final dominant = colors.first;
    final highlight = colors.length > 1 ? colors[1] : dominant;
    final anchor = colors.length > 3 ? colors[3] : dominant;
    final edge = _signalColor(dominant, lightness: 0.66);
    final accent = _signalColor(highlight, lightness: 0.64);
    final surface = Color.lerp(const Color(0xFF202729), dominant, 0.28)!;
    final surfaceDeep = Color.lerp(const Color(0xFF080C0D), anchor, 0.18)!;
    final surfaceRaised = Color.lerp(const Color(0xFF30383A), highlight, 0.20)!;
    final foreground = Color.lerp(const Color(0xFFF4F0E7), edge, 0.06)!;
    final secondaryForeground = Color.lerp(
      const Color(0xFFD6E1DE),
      edge,
      0.16,
    )!.withValues(alpha: 0.78);

    return CassettePlayerPalette(
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
}

Color _signalColor(Color source, {required double lightness}) {
  final hsl = HSLColor.fromColor(source);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.52, 0.82))
      .withLightness(lightness)
      .toColor();
}
