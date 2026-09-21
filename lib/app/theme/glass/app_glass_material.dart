import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../skin/app_skin_theme.dart';

/// Material values from the official Apple Music demo (_kPillGlass and
/// _barGlassSettings), with only the base hue supplied by the active skin.
/// https://github.com/sdegenaar/liquid_glass_widgets/blob/main/example/lib/apple_music/apple_music_demo.dart
abstract final class AppGlassMaterial {
  /// Matches liquid_glass_widgets 1.6.1's kDefaultSheetSettings.
  /// The preset is internal, so reproduce its values through the public API.
  /// Used for the half-open surface; full expansion uses the solid fill.
  static const sheet = LiquidGlassSettings(
    glassColor: Color(0x1FFFFFFF),
    thickness: 10,
    blur: 10,
    lightIntensity: 0.7,
    lightAngle: 2.356194,
    chromaticAberration: 0,
    refractiveIndex: 0.15,
    saturation: 1.2,
    ambientStrength: 0.4,
  );

  /// Keep the official optics, but use the library's brightness-specific tint
  /// and documented 35% contrast backer for readable content over busy covers.
  static LiquidGlassSettings sheetFor(BuildContext context) {
    final theme = Theme.of(context);
    final variant = theme.brightness == Brightness.dark
        ? GlassThemeVariant.dark
        : GlassThemeVariant.light;
    final surface =
        theme.extension<AppSkinTheme>()?.config.colors.bottomSheetBackground ??
        theme.colorScheme.surface;
    return sheet.copyWith(
      glassColor: variant.settings?.glassColor ?? sheet.glassColor,
      backerColor: surface.withValues(alpha: 0.35),
    );
  }

  static LiquidGlassSettings settings(
    BuildContext context, {
    bool navigation = false,
  }) {
    final theme = Theme.of(context);
    final color =
        theme.extension<AppSkinTheme>()?.config.colors.fixedControlSurface ??
        theme.colorScheme.surface;
    return LiquidGlassSettings(
      glassColor: color.withAlpha(navigation ? 0xAA : 0xCC),
      thickness: 30,
      blur: 2,
      lightIntensity: navigation ? 0.2 : 0.18,
      chromaticAberration: .01,
      saturation: 1.2,
      fresnelStrength: 0,
    );
  }
}
