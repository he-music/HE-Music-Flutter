import 'package:flutter/material.dart';

import 'app_skin_models.dart';

@immutable
class AppSkinTheme extends ThemeExtension<AppSkinTheme> {
  const AppSkinTheme({
    required this.config,
    required this.icons,
    required this.showContentBackground,
  });

  final AppSkinBrightnessConfig config;
  final AppSkinIconCatalog icons;
  final bool showContentBackground;

  /// Wallpaper playback controls share tint and opacity across UI styles.
  bool get usesTranslucentPlaybackSurfaces =>
      config.background.wallpaper.descriptor != null &&
      config.colors.scaffoldBackground.a == 0;

  Color get miniPlayerBackgroundColor =>
      config.colors.fixedControlSurface.withValues(
        alpha: usesTranslucentPlaybackSurfaces
            ? config.surfaces.miniPlayerOpacity
            : 1,
      );

  Color get navigationBackgroundColor =>
      config.colors.fixedControlSurface.withValues(
        alpha: usesTranslucentPlaybackSurfaces
            ? config.surfaces.navigationOpacity
            : 1,
      );

  /// All page content cards use the same preference and skin opacity.
  Color get contentBackgroundColor {
    final surface = config.colors.scrollingContentSurface;
    return surface.withValues(
      alpha: showContentBackground
          ? surface.a * config.surfaces.scrollingContentOpacity
          : 0,
    );
  }

  @override
  AppSkinTheme copyWith({
    AppSkinBrightnessConfig? config,
    AppSkinIconCatalog? icons,
    bool? showContentBackground,
  }) {
    return AppSkinTheme(
      config: config ?? this.config,
      icons: icons ?? this.icons,
      showContentBackground:
          showContentBackground ?? this.showContentBackground,
    );
  }

  @override
  AppSkinTheme lerp(covariant AppSkinTheme? other, double t) {
    if (other == null) {
      return this;
    }
    return AppSkinTheme(
      config: AppSkinBrightnessConfig.lerp(config, other.config, t),
      icons: t < 0.5 ? icons : other.icons,
      showContentBackground: t < 0.5
          ? showContentBackground
          : other.showContentBackground,
    );
  }
}
