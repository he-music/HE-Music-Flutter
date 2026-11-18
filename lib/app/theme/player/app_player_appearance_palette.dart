import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import '../../config/app_player_appearance.dart';
import 'app_player_scene_palette.dart';

/// One hue family with perceptual tones keeps dark surfaces and bright accents related.
List<Color> playerAppearanceColors(
  List<Color> colors,
  AppPlayerAppearance appearance,
) {
  final source = Color(
    appearance.backgroundColor ??
        (colors.isEmpty ? 0xff477d8a : colors.first.toARGB32()),
  );
  final hct = Hct.fromInt(source.toARGB32());
  final chroma = switch (appearance.mood) {
    AppPlayerColorMood.soft => math.min(hct.chroma, 20.0),
    AppPlayerColorMood.vivid => hct.chroma.clamp(28.0, 56.0),
    AppPlayerColorMood.dark => hct.chroma.clamp(16.0, 36.0),
  };
  final tones = appearance.mood == AppPlayerColorMood.dark
      ? [16.0, 26.0, 12.0, 8.0]
      : [27.0, 39.0, 21.0, 12.0];
  return [
    for (var i = 0; i < tones.length; i++)
      Color(
        Hct.from(
          hct.hue + (i == 1 ? 12 : 0),
          hct.chroma < 8 ? hct.chroma : chroma,
          tones[i],
        ).toInt(),
      ),
  ];
}

/// Retargets from the visible colors when another cover or choice arrives mid-fade.
class PlayerPaletteTween extends Tween<List<Color>> {
  PlayerPaletteTween(List<Color> colors) : super(begin: colors, end: colors);

  @override
  List<Color> lerp(double t) => [
    for (var i = 0; i < end!.length; i++)
      Color.lerp(begin![i % begin!.length], end![i], t)!,
  ];
}

PlayerScenePalette playerAppearanceScenePalette(
  PlayerScenePalette base,
  List<Color> artworkColors,
  AppPlayerAppearance appearance,
) {
  final colors = playerAppearanceColors(artworkColors, appearance);
  final seed = Hct.fromInt(colors.first.toARGB32());
  final accent = appearance.accentColor == null
      ? Color(
          Hct.from(
            seed.hue,
            seed.chroma < 8
                ? 6
                : appearance.mood == AppPlayerColorMood.soft
                ? 24
                : 48,
            82,
          ).toInt(),
        )
      : Color(appearance.accentColor!);
  return base.copyWith(
    surface: colors[0],
    surfaceDeep: colors[3],
    surfaceRaised: colors[1],
    accent: accent,
    edge: Color(Hct.from(seed.hue, 18, 86).toInt()),
    foreground: Color(Hct.from(seed.hue, 5, 98).toInt()),
    secondaryForeground: Color(Hct.from(seed.hue, 12, 78).toInt()),
    onAccent: accent.computeLuminance() > .35
        ? const Color(0xff101418)
        : Colors.white,
  );
}
