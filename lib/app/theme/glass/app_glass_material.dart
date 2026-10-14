import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../skin/app_skin_theme.dart';

/// Official Apple Music navigation optics and sheet optics for frosted music
/// controls, with only the backing hue supplied by the active skin.
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

  /// Keep the package's sheet optics and add only a skin-colored backer.
  /// The backer reduces background noise while the library material handles
  /// the brightness-aware glass rendering.
  static LiquidGlassSettings sheetFor(BuildContext context) {
    final theme = Theme.of(context);
    final surface =
        theme.extension<AppSkinTheme>()?.config.colors.bottomSheetBackground ??
        theme.colorScheme.surface;
    return sheet.copyWith(backerColor: surface.withValues(alpha: 0.35));
  }

  /// Skin-colored backing shared by playback and music category controls.
  static Color controlSurfaceColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppSkinTheme>()?.config.colors.fixedControlSurface ??
        theme.colorScheme.surface;
  }

  /// Use the official sheet optics for frosted playback controls. Only the
  /// backing opacity changes as a cover collapses beneath a pinned bar.
  static LiquidGlassSettings musicControls({
    required Color surface,
    double collapseProgress = 1,
  }) {
    final collapse = collapseProgress.clamp(0.0, 1.0);
    return sheet.copyWith(
      backerColor: surface.withValues(alpha: 0.54 + 0.18 * collapse),
    );
  }

  static LiquidGlassSettings settings(
    BuildContext context, {
    bool navigation = false,
  }) {
    final color = controlSurfaceColor(context);
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
