import 'package:flutter/material.dart';

import 'app_skin_models.dart';

@immutable
class AppSkinTheme extends ThemeExtension<AppSkinTheme> {
  const AppSkinTheme({required this.config, required this.icons});

  final AppSkinBrightnessConfig config;
  final AppSkinIconCatalog icons;

  @override
  AppSkinTheme copyWith({
    AppSkinBrightnessConfig? config,
    AppSkinIconCatalog? icons,
  }) {
    return AppSkinTheme(
      config: config ?? this.config,
      icons: icons ?? this.icons,
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
    );
  }
}
