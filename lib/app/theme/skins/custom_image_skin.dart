import 'package:flutter/material.dart';

import '../../config/app_custom_skin_config.dart';
import '../../config/app_theme_accent.dart';
import '../skin/app_skin_models.dart';
import 'classic_skin.dart';

AppSkinPackage customImageSkin(AppCustomSkinConfig config) {
  final seed = Color(config.seedColor);
  final base = classicSkinForAccent(AppThemeAccent.graphite);
  final lightScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );
  final darkScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  );
  final lightAsset = _asset(config.lightAssetPath);
  final darkAsset = _asset(config.darkAssetPath);
  return base.copyWith(
    metadata: AppSkinMetadata(
      id: 'custom_image',
      nameKey: 'settings.skin.custom.name',
      descriptionKey: 'settings.skin.custom.description',
      allowsManualAccent: false,
      lightPreview: AppSkinAssetSlot.asset(lightAsset),
      darkPreview: AppSkinAssetSlot.asset(darkAsset),
      source: AppSkinSource.userGenerated,
    ),
    light: _brightnessConfig(
      scheme: lightScheme,
      wallpaper: lightAsset,
      alignment: config.focalAlignment,
    ),
    dark: _brightnessConfig(
      scheme: darkScheme,
      wallpaper: darkAsset,
      alignment: config.focalAlignment,
    ),
  );
}

AppSkinAssetDescriptor _asset(String path) {
  return AppSkinAssetDescriptor(
    path: path,
    type: AppSkinAssetType.rasterImage,
    source: AppSkinAssetSource.applicationSupport,
  );
}

AppSkinBrightnessConfig _brightnessConfig({
  required ColorScheme scheme,
  required AppSkinAssetDescriptor wallpaper,
  required Alignment alignment,
}) {
  final isDark = scheme.brightness == Brightness.dark;
  return AppSkinBrightnessConfig(
    colorScheme: scheme,
    colors: AppSkinColors(
      scaffoldBackground: Colors.transparent,
      canvasBackground: Colors.transparent,
      wallpaperFallback: scheme.surface,
      backgroundOverlay: Colors.transparent,
      cardBackground: scheme.surfaceContainerHigh.withValues(
        alpha: isDark ? 0.62 : 0.6,
      ),
      inputBackground: scheme.surfaceContainerHighest,
      navigationBackground: scheme.surface,
      navigationIndicator: scheme.primaryContainer,
      bottomSheetBackground: scheme.surface,
      dialogBackground: scheme.surfaceContainerHigh,
      divider: scheme.outlineVariant,
      snackBarBackground: scheme.inverseSurface,
      fixedControlSurface: scheme.surfaceContainerHigh,
      scrollingContentSurface: scheme.surfaceContainer,
      border: scheme.outlineVariant,
      selectionIndicator: scheme.primary,
      shadow: Colors.black,
    ),
    surfaces: AppSkinSurfaces(
      searchOpacity: isDark ? 0.82 : 0.88,
      miniPlayerOpacity: isDark ? 0.86 : 0.9,
      navigationOpacity: isDark ? 0.9 : 0.94,
      scrollingContentOpacity: isDark ? 0.62 : 0.6,
      bottomSheetOpacity: 0.96,
    ),
    geometry: const AppSkinGeometry(
      controlRadius: 18,
      cardRadius: 14,
      bottomSheetRadius: 28,
      blurSigma: 8,
      borderWidth: 0.6,
      shadowOpacity: 0.1,
      shadowBlurRadius: 12,
      shadowOffset: Offset(0, 4),
      showNavigationIndicatorPill: true,
    ),
    background: AppSkinBackgroundConfig(
      wallpaper: AppSkinAssetSlot.asset(wallpaper),
      animation: const AppSkinAnimationDescriptor.none(),
      fit: BoxFit.cover,
      alignment: alignment,
      overlayColor: Colors.transparent,
    ),
  );
}
