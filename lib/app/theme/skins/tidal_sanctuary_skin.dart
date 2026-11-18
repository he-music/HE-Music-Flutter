import 'package:flutter/material.dart';

import '../../config/app_theme_accent.dart';
import '../skin/app_skin_models.dart';
import 'classic_skin.dart';

/// Sunlit shallows and a bioluminescent reef share the same quiet sand channel.
AppSkinPackage tidalSanctuarySkin() {
  final base = classicSkinForAccent(AppThemeAccent.graphite);
  return base.copyWith(
    metadata: AppSkinMetadata(
      id: 'tidal_sanctuary',
      nameKey: 'settings.skin.tidal_sanctuary.name',
      descriptionKey: 'settings.skin.tidal_sanctuary.description',
      allowsManualAccent: false,
      lightPreview: _image('preview_light.png'),
      darkPreview: _image('preview_dark.png'),
    ),
    light: _config(Brightness.light),
    dark: _config(Brightness.dark),
    icons: base.icons.copyWith(
      overrides: {
        for (final entry in _icons.entries)
          entry.key: base.icons[entry.key]!.copyWith(
            asset: AppSkinAssetSlot.asset(
              AppSkinAssetDescriptor(
                path: 'assets/skins/tidal_sanctuary/icons/${entry.value}.svg',
                type: AppSkinAssetType.svg,
                themeColorSource: const Color(0xFF438F9B),
              ),
            ),
          ),
      },
    ),
  );
}

AppSkinAssetSlot _image(String name) => AppSkinAssetSlot.asset(
  AppSkinAssetDescriptor(
    path: 'assets/skins/tidal_sanctuary/$name',
    type: AppSkinAssetType.rasterImage,
  ),
);

const _icons = <AppSkinIconRole, String>{
  AppSkinIconRole.navigationHome: 'home',
  AppSkinIconRole.navigationHomeSelected: 'home',
  AppSkinIconRole.navigationLibrary: 'library',
  AppSkinIconRole.navigationLibrarySelected: 'library',
  AppSkinIconRole.navigationMy: 'person',
  AppSkinIconRole.navigationMySelected: 'person',
  AppSkinIconRole.homePlaylist: 'library',
  AppSkinIconRole.myPlaylist: 'library',
  AppSkinIconRole.myLocalMusic: 'library',
  AppSkinIconRole.search: 'search',
  AppSkinIconRole.searchSubmit: 'search',
  AppSkinIconRole.songSearchSameName: 'search',
  AppSkinIconRole.miniPlayerPlay: 'play',
  AppSkinIconRole.songPlay: 'play',
  AppSkinIconRole.batchPlay: 'play',
  AppSkinIconRole.miniPlayerPause: 'pause',
  AppSkinIconRole.miniPlayerQueue: 'queue',
  AppSkinIconRole.songFavorite: 'heart',
  AppSkinIconRole.songUnfavorite: 'heart',
  AppSkinIconRole.myCollection: 'heart',
  AppSkinIconRole.settingsSkin: 'tide',
  AppSkinIconRole.settingsAppearance: 'tide',
  AppSkinIconRole.settingsSkinAnimation: 'tide',
};

AppSkinBrightnessConfig _config(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF207B83),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFF99E5DA) : const Color(0xFF145E68),
        onPrimary: dark ? const Color(0xFF063D46) : const Color(0xFFF6FFFA),
        primaryContainer: dark
            ? const Color(0xFF205461)
            : const Color(0xFFBFE4DE),
        onPrimaryContainer: dark
            ? const Color(0xFFD4F8EF)
            : const Color(0xFF123F48),
        secondary: dark ? const Color(0xFFE0BFD7) : const Color(0xFF80545D),
        onSecondary: dark ? const Color(0xFF453046) : const Color(0xFFFFF7F4),
        secondaryContainer: dark
            ? const Color(0xFF58425C)
            : const Color(0xFFF3DAD4),
        onSecondaryContainer: dark
            ? const Color(0xFFFFE5F1)
            : const Color(0xFF50363E),
        tertiary: dark ? const Color(0xFFB8D9EB) : const Color(0xFF3F6378),
        surface: dark ? const Color(0xFF102F43) : const Color(0xFFEAF3ED),
        onSurface: dark ? const Color(0xFFECF7F5) : const Color(0xFF153A43),
        onSurfaceVariant: dark
            ? const Color(0xFFBCD7DF)
            : const Color(0xFF3E6169),
        surfaceContainerLowest: dark
            ? const Color(0xFF092336)
            : const Color(0xFFF6FAF1),
        surfaceContainerLow: dark
            ? const Color(0xFF12364A)
            : const Color(0xFFEDF5ED),
        surfaceContainer: dark
            ? const Color(0xFF193D50)
            : const Color(0xFFE0EDE5),
        surfaceContainerHigh: dark
            ? const Color(0xFF234B5D)
            : const Color(0xFFD2E5DE),
        surfaceContainerHighest: dark
            ? const Color(0xFF305B6B)
            : const Color(0xFFC2DBD5),
        outline: dark ? const Color(0xFF84ACB7) : const Color(0xFF648B90),
        outlineVariant: dark
            ? const Color(0xFF3F6477)
            : const Color(0xFFA6C6BF),
      );
  final surface = dark ? const Color(0xFF143E52) : const Color(0xFFEDF6EB);
  final content = dark ? const Color(0xFF14384B) : const Color(0xFFE7F2E9);
  final overlay = dark
      ? const Color(0xFF062638).withValues(alpha: 0.36)
      : const Color(0xFFEEF7EB).withValues(alpha: 0.30);
  return AppSkinBrightnessConfig(
    sheetMotif: AppSkinSheetMotif.tidal,
    colorScheme: scheme,
    colors: AppSkinColors(
      scaffoldBackground: Colors.transparent,
      canvasBackground: Colors.transparent,
      wallpaperFallback: dark
          ? const Color(0xFF0B3047)
          : const Color(0xFFB8DCD5),
      backgroundOverlay: overlay,
      cardBackground: content.withValues(alpha: dark ? 0.68 : 0.74),
      inputBackground: surface.withValues(alpha: 0.90),
      navigationBackground: surface.withValues(alpha: dark ? 0.62 : 0.64),
      navigationIndicator: scheme.primary.withValues(alpha: 0.14),
      bottomSheetBackground: scheme.surface,
      dialogBackground: scheme.surface,
      divider: scheme.outlineVariant.withValues(alpha: 0.42),
      snackBarBackground: const Color(0xFF214E5B),
      fixedControlSurface: surface,
      scrollingContentSurface: content,
      border: scheme.outlineVariant.withValues(alpha: 0.50),
      selectionIndicator: scheme.primary,
      shadow: const Color(0xFF08303F),
    ),
    surfaces: AppSkinSurfaces(
      searchOpacity: 0.90,
      miniPlayerOpacity: dark ? 0.80 : 0.84,
      navigationOpacity: dark ? 0.62 : 0.64,
      scrollingContentOpacity: dark ? 0.68 : 0.74,
      bottomSheetOpacity: 1,
    ),
    geometry: const AppSkinGeometry(
      controlRadius: 22,
      cardRadius: 20,
      bottomSheetRadius: 28,
      blurSigma: 12,
      borderWidth: 0.65,
      shadowOpacity: 0.08,
      shadowBlurRadius: 10,
      shadowOffset: Offset(0, 3),
      showNavigationIndicatorPill: true,
    ),
    background: AppSkinBackgroundConfig(
      wallpaper: _image('wallpaper_${dark ? 'dark' : 'light'}.jpg'),
      animation: AppSkinAnimationDescriptor.rive(
        asset: const AppSkinAssetDescriptor(
          path: 'assets/skins/tidal_sanctuary/ambient.riv',
          type: AppSkinAssetType.rive,
        ),
        artboard: dark ? 'TidalNight' : 'TidalDay',
        stateMachine: 'AmbientLoop',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        opacity: dark ? 0.94 : 0.90,
      ),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      overlayColor: overlay,
    ),
  );
}
