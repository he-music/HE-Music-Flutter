import 'package:flutter/material.dart';

import '../../config/app_theme_accent.dart';
import '../skin/app_skin_models.dart';
import 'classic_skin.dart';

AppSkinPackage forestSanctuarySkin() {
  final base = classicSkinForAccent(AppThemeAccent.graphite);
  return base.copyWith(
    metadata: const AppSkinMetadata(
      id: 'forest_sanctuary',
      nameKey: 'settings.skin.forest_sanctuary.name',
      descriptionKey: 'settings.skin.forest_sanctuary.description',
      allowsManualAccent: false,
      lightPreview: AppSkinAssetSlot.asset(
        AppSkinAssetDescriptor(
          path: 'assets/skins/forest_sanctuary/preview_light.png',
          type: AppSkinAssetType.rasterImage,
        ),
      ),
      darkPreview: AppSkinAssetSlot.asset(
        AppSkinAssetDescriptor(
          path: 'assets/skins/forest_sanctuary/preview_dark.png',
          type: AppSkinAssetType.rasterImage,
        ),
      ),
    ),
    light: _config(Brightness.light),
    dark: _config(Brightness.dark),
    icons: base.icons.copyWith(
      overrides: {
        for (final entry in _icons.entries)
          entry.key: base.icons[entry.key]!.copyWith(
            asset: AppSkinAssetSlot.asset(
              AppSkinAssetDescriptor(
                path: 'assets/skins/forest_sanctuary/icons/${entry.value}.svg',
                type: AppSkinAssetType.svg,
                themeColorSource: const Color(0xFF7DA88B),
              ),
            ),
          ),
      },
    ),
  );
}

const _icons = <AppSkinIconRole, String>{
  AppSkinIconRole.navigationHome: 'home',
  AppSkinIconRole.navigationHomeSelected: 'home',
  AppSkinIconRole.navigationLibrary: 'library',
  AppSkinIconRole.navigationLibrarySelected: 'library',
  AppSkinIconRole.navigationMy: 'person',
  AppSkinIconRole.navigationMySelected: 'person',
  AppSkinIconRole.search: 'search',
  AppSkinIconRole.songSearchSameName: 'search',
  AppSkinIconRole.miniPlayerPlay: 'play',
  AppSkinIconRole.songPlay: 'play',
  AppSkinIconRole.batchPlay: 'play',
  AppSkinIconRole.miniPlayerPause: 'pause',
  AppSkinIconRole.miniPlayerQueue: 'queue',
  AppSkinIconRole.homePlaylist: 'library',
  AppSkinIconRole.myPlaylist: 'library',
  AppSkinIconRole.myLocalMusic: 'library',
  AppSkinIconRole.songFavorite: 'heart',
  AppSkinIconRole.songUnfavorite: 'heart',
  AppSkinIconRole.myCollection: 'heart',
  AppSkinIconRole.settingsSkin: 'leaf',
  AppSkinIconRole.settingsAppearance: 'leaf',
  AppSkinIconRole.settingsSkinAnimation: 'leaf',
};

AppSkinBrightnessConfig _config(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF486F4C),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFFD8DDA8) : const Color(0xFF365B40),
        onPrimary: dark ? const Color(0xFF233D2F) : const Color(0xFFFFFCED),
        primaryContainer: dark
            ? const Color(0xFF3B5943)
            : const Color(0xFFD9E3BC),
        onPrimaryContainer: dark
            ? const Color(0xFFF0F0CC)
            : const Color(0xFF233D2F),
        secondary: dark ? const Color(0xFFE9CB8B) : const Color(0xFF7C602A),
        onSecondary: dark ? const Color(0xFF3D3017) : const Color(0xFFFFFCED),
        secondaryContainer: dark
            ? const Color(0xFF574B2E)
            : const Color(0xFFF1E4BB),
        onSecondaryContainer: dark
            ? const Color(0xFFFFEBC1)
            : const Color(0xFF3D3017),
        surface: dark ? const Color(0xFF142F2D) : const Color(0xFFF1F0DF),
        onSurface: dark ? const Color(0xFFF3F0DA) : const Color(0xFF243D32),
        onSurfaceVariant: dark
            ? const Color(0xFFC9D8C9)
            : const Color(0xFF486052),
        surfaceContainerLowest: dark
            ? const Color(0xFF0B2223)
            : const Color(0xFFFAF8E9),
        surfaceContainerLow: dark
            ? const Color(0xFF12302C)
            : const Color(0xFFF3F2E1),
        surfaceContainer: dark
            ? const Color(0xFF1B3931)
            : const Color(0xFFE8EAD3),
        surfaceContainerHigh: dark
            ? const Color(0xFF29493D)
            : const Color(0xFFDFE4C7),
        surfaceContainerHighest: dark
            ? const Color(0xFF365847)
            : const Color(0xFFD3DDBA),
        outline: dark ? const Color(0xFF91AB91) : const Color(0xFF75856A),
        outlineVariant: dark
            ? const Color(0xFF4C6B54)
            : const Color(0xFFB2BDA0),
      );
  final surface = dark ? const Color(0xFF193C32) : const Color(0xFFF2F0DC);
  final content = dark ? const Color(0xFF12372F) : const Color(0xFFEEF0D9);
  final overlay = dark
      ? const Color(0xFF082523).withValues(alpha: 0.36)
      : const Color(0xFFF3F1DC).withValues(alpha: 0.30);
  return AppSkinBrightnessConfig(
    visualStyle: AppSkinVisualStyle.woodland,
    colorScheme: scheme,
    colors: AppSkinColors(
      scaffoldBackground: Colors.transparent,
      canvasBackground: Colors.transparent,
      wallpaperFallback: dark
          ? const Color(0xFF102F30)
          : const Color(0xFFDAE2C0),
      backgroundOverlay: overlay,
      cardBackground: content.withValues(alpha: dark ? 0.68 : 0.76),
      inputBackground: surface.withValues(alpha: 0.92),
      navigationBackground: surface.withValues(alpha: dark ? 0.54 : 0.58),
      navigationIndicator: scheme.secondary.withValues(alpha: 0.16),
      bottomSheetBackground: scheme.surface,
      dialogBackground: scheme.surface,
      divider: scheme.outlineVariant.withValues(alpha: 0.42),
      snackBarBackground: const Color(0xFF264638),
      fixedControlSurface: surface,
      scrollingContentSurface: content,
      border: scheme.outlineVariant.withValues(alpha: 0.5),
      selectionIndicator: scheme.secondary,
      shadow: const Color(0xFF08291F),
    ),
    surfaces: AppSkinSurfaces(
      searchOpacity: 0.92,
      miniPlayerOpacity: dark ? 0.76 : 0.80,
      navigationOpacity: dark ? 0.54 : 0.58,
      scrollingContentOpacity: dark ? 0.68 : 0.76,
      bottomSheetOpacity: 1,
    ),
    geometry: const AppSkinGeometry(
      controlRadius: 24,
      cardRadius: 20,
      bottomSheetRadius: 28,
      blurSigma: 12,
      borderWidth: 0.7,
      shadowOpacity: 0.10,
      shadowBlurRadius: 12,
      shadowOffset: Offset(0, 4),
      showNavigationIndicatorPill: true,
    ),
    background: AppSkinBackgroundConfig(
      wallpaper: AppSkinAssetSlot.asset(
        AppSkinAssetDescriptor(
          path: 'assets/skins/forest_sanctuary/scene-${dark ? 1 : 0}.jpg',
          type: AppSkinAssetType.rasterImage,
        ),
      ),
      animation: AppSkinAnimationDescriptor.rive(
        asset: const AppSkinAssetDescriptor(
          path: 'assets/skins/forest_sanctuary/ambient.riv',
          type: AppSkinAssetType.rive,
        ),
        artboard: dark ? 'ForestNight' : 'ForestDay',
        stateMachine: 'AmbientLoop',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        opacity: dark ? 0.96 : 0.85,
      ),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      overlayColor: overlay,
    ),
  );
}
