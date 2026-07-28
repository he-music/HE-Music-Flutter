import 'package:flutter/material.dart';

import '../../config/app_theme_accent.dart';
import '../skin/app_skin_models.dart';
import 'classic_skin.dart';

AppSkinPackage starlitMelodySkin() {
  // 评估版先验证明暗壁纸与色板，专属图标继续继承固定石墨经典回退。
  final base = classicSkinForAccent(AppThemeAccent.graphite);
  return base.copyWith(
    metadata: const AppSkinMetadata(
      id: 'starlit_melody',
      nameKey: 'settings.skin.starlit_melody.name',
      descriptionKey: 'settings.skin.starlit_melody.description',
      allowsManualAccent: false,
      lightPreview: AppSkinAssetSlot.asset(
        AppSkinAssetDescriptor(
          path: 'assets/skins/starlit_melody/preview_light.png',
          type: AppSkinAssetType.rasterImage,
        ),
      ),
      darkPreview: AppSkinAssetSlot.asset(
        AppSkinAssetDescriptor(
          path: 'assets/skins/starlit_melody/preview_dark.png',
          type: AppSkinAssetType.rasterImage,
        ),
      ),
    ),
    light: _lightBrightnessConfig(),
    dark: _darkBrightnessConfig(),
  );
}

const _backgroundFit = BoxFit.cover;
const _backgroundAlignment = Alignment.center;
const _geometry = AppSkinGeometry(
  controlRadius: 18,
  cardRadius: 16,
  bottomSheetRadius: 26,
  blurSigma: 8,
  borderWidth: 0.8,
  shadowOpacity: 0.08,
  shadowBlurRadius: 10,
  shadowOffset: Offset(0, 3),
  showNavigationIndicatorPill: true,
);

AppSkinBrightnessConfig _lightBrightnessConfig() {
  const pearl = Color(0xFFF8F7FC);
  const overlay = Color(0x24FFFFFF);
  final scheme = _lightColorScheme();
  return AppSkinBrightnessConfig(
    colorScheme: scheme,
    colors: AppSkinColors(
      scaffoldBackground: Colors.transparent,
      canvasBackground: Colors.transparent,
      wallpaperFallback: const Color(0xFFEAF6FB),
      backgroundOverlay: overlay,
      cardBackground: const Color(0x00F8F7FC),
      inputBackground: const Color(0xE8F8F7FC),
      navigationBackground: const Color(0xF2F8F7FC),
      navigationIndicator: const Color(0x2E00677A),
      bottomSheetBackground: const Color(0xFAF8F7FC),
      dialogBackground: const Color(0xFCF8F7FC),
      divider: const Color(0x99C9C5CE),
      snackBarBackground: const Color(0xFF17202A),
      fixedControlSurface: pearl,
      scrollingContentSurface: pearl,
      border: const Color(0xFFB3C2CC),
      selectionIndicator: const Color(0xFF00677A),
      shadow: const Color(0xFF111521),
    ),
    surfaces: const AppSkinSurfaces(
      searchOpacity: 0.9,
      miniPlayerOpacity: 0.94,
      navigationOpacity: 0.96,
      scrollingContentOpacity: 0,
      bottomSheetOpacity: 0.98,
    ),
    geometry: _geometry,
    background: const AppSkinBackgroundConfig(
      wallpaper: AppSkinAssetSlot.asset(
        AppSkinAssetDescriptor(
          path: 'assets/skins/starlit_melody/wallpaper_light.png',
          type: AppSkinAssetType.rasterImage,
        ),
      ),
      animation: AppSkinAnimationDescriptor.none(),
      fit: _backgroundFit,
      alignment: _backgroundAlignment,
      overlayColor: overlay,
    ),
  );
}

AppSkinBrightnessConfig _darkBrightnessConfig() {
  const night = Color(0xFF111521);
  const fixedSurface = Color(0xFF294A61);
  const scrollingSurface = Color(0xFF29475A);
  const overlay = Color(0x24111521);
  final scheme = _darkColorScheme();
  return AppSkinBrightnessConfig(
    colorScheme: scheme,
    colors: const AppSkinColors(
      scaffoldBackground: Colors.transparent,
      canvasBackground: Colors.transparent,
      wallpaperFallback: night,
      backgroundOverlay: overlay,
      cardBackground: Color(0x0029475A),
      inputBackground: Color(0xC2294A61),
      navigationBackground: Color(0xD1294A61),
      navigationIndicator: Color(0x3DF2CE67),
      bottomSheetBackground: Color(0xED1B3041),
      dialogBackground: Color(0xF0213A4C),
      divider: Color(0x9949444E),
      snackBarBackground: Color(0xFF29475A),
      fixedControlSurface: fixedSurface,
      scrollingContentSurface: scrollingSurface,
      border: Color(0xFF607B8D),
      selectionIndicator: Color(0xFF78D5E7),
      shadow: Color(0xFF07111B),
    ),
    surfaces: const AppSkinSurfaces(
      searchOpacity: 0.76,
      miniPlayerOpacity: 0.78,
      navigationOpacity: 0.82,
      scrollingContentOpacity: 0,
      bottomSheetOpacity: 0.94,
    ),
    geometry: _geometry,
    background: const AppSkinBackgroundConfig(
      wallpaper: AppSkinAssetSlot.asset(
        AppSkinAssetDescriptor(
          path:
              'assets/skins/starlit_melody/'
              'wallpaper_dark_evaluation.png',
          type: AppSkinAssetType.rasterImage,
        ),
      ),
      animation: AppSkinAnimationDescriptor.none(),
      fit: _backgroundFit,
      alignment: _backgroundAlignment,
      overlayColor: overlay,
    ),
  );
}

ColorScheme _lightColorScheme() {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00677A),
    secondary: const Color(0xFFB72F5B),
    tertiary: const Color(0xFF735C00),
  );
  return base.copyWith(
    primary: const Color(0xFF00677A),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFA6EEFF),
    onPrimaryContainer: const Color(0xFF001F26),
    secondary: const Color(0xFFB72F5B),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFFFD9E3),
    onSecondaryContainer: const Color(0xFF3D001B),
    tertiary: const Color(0xFF735C00),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFFBE08D),
    onTertiaryContainer: const Color(0xFF241A00),
    surface: const Color(0xFFF8F7FC),
    onSurface: const Color(0xFF17202A),
    onSurfaceVariant: const Color(0xFF46515C),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF4F3F8),
    surfaceContainer: const Color(0xFFEFEDF4),
    surfaceContainerHigh: const Color(0xFFE9E7EF),
    surfaceContainerHighest: const Color(0xFFE3E1E9),
    outline: const Color(0xFF77737C),
    outlineVariant: const Color(0xFFC9C5CE),
    error: const Color(0xFFBA1A1A),
    onError: Colors.white,
  );
}

ColorScheme _darkColorScheme() {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF78D5E7),
    secondary: const Color(0xFFFFB0C8),
    tertiary: const Color(0xFFF2CE67),
    brightness: Brightness.dark,
  );
  return base.copyWith(
    primary: const Color(0xFF78D5E7),
    onPrimary: const Color(0xFF00363F),
    primaryContainer: const Color(0xFF235D6A),
    onPrimaryContainer: const Color(0xFFD5F7FF),
    secondary: const Color(0xFFFFB0C8),
    onSecondary: const Color(0xFF5F1132),
    secondaryContainer: const Color(0xFF6F3B4F),
    onSecondaryContainer: const Color(0xFFFFE3EB),
    tertiary: const Color(0xFFF2CE67),
    onTertiary: const Color(0xFF3B2F00),
    tertiaryContainer: const Color(0xFF65551C),
    onTertiaryContainer: const Color(0xFFFFF0B8),
    surface: const Color(0xFF213A4C),
    onSurface: const Color(0xFFF0EDF5),
    onSurfaceVariant: const Color(0xFFD3CBD7),
    surfaceContainerLowest: const Color(0xFF152737),
    surfaceContainerLow: const Color(0xFF1B3041),
    surfaceContainer: const Color(0xFF213A4C),
    surfaceContainerHigh: const Color(0xFF29475A),
    surfaceContainerHighest: const Color(0xFF355A70),
    outline: const Color(0xFFA6BBC8),
    outlineVariant: const Color(0xFF607B8D),
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
  );
}
