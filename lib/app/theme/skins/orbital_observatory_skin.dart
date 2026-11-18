import 'package:flutter/material.dart';

import '../../config/app_theme_accent.dart';
import '../skin/app_skin_models.dart';
import 'classic_skin.dart';

/// An unobstructed orbital scene with steady stars and localized atmosphere.
AppSkinPackage orbitalObservatorySkin() {
  final base = classicSkinForAccent(AppThemeAccent.graphite);
  return base.copyWith(
    metadata: AppSkinMetadata(
      id: 'orbital_observatory',
      nameKey: 'settings.skin.orbital_observatory.name',
      descriptionKey: 'settings.skin.orbital_observatory.description',
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
                path:
                    'assets/skins/orbital_observatory/icons/${entry.value}.svg',
                type: AppSkinAssetType.svg,
                themeColorSource: const Color(0xFF6FB7CE),
              ),
            ),
          ),
      },
    ),
  );
}

AppSkinAssetSlot _image(String name) => AppSkinAssetSlot.asset(
  AppSkinAssetDescriptor(
    path: 'assets/skins/orbital_observatory/$name',
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
  AppSkinIconRole.songDownload: 'download',
  AppSkinIconRole.myDownloads: 'download',
  AppSkinIconRole.more: 'more',
  AppSkinIconRole.settingsSkin: 'orbit',
  AppSkinIconRole.settingsAppearance: 'orbit',
  AppSkinIconRole.settingsSkinAnimation: 'orbit',
};

AppSkinBrightnessConfig _config(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? const Color(0xFF102638) : const Color(0xFFEAF2F7);
  final content = dark ? const Color(0xFF132E43) : const Color(0xFFEAF2F7);
  final primary = dark ? const Color(0xFF82DDEB) : const Color(0xFF005B79);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF137A9D),
        brightness: brightness,
      ).copyWith(
        primary: primary,
        onPrimary: dark ? const Color(0xFF003744) : Colors.white,
        primaryContainer: dark
            ? const Color(0xFF164C61)
            : const Color(0xFFBCE9F5),
        onPrimaryContainer: dark
            ? const Color(0xFFD5F7FF)
            : const Color(0xFF072E40),
        secondary: dark ? const Color(0xFFA3DDBF) : const Color(0xFF32674E),
        tertiary: dark ? const Color(0xFFE2C18C) : const Color(0xFF785B28),
        surface: surface,
        onSurface: dark ? const Color(0xFFF0F5F8) : const Color(0xFF0B1D2B),
        onSurfaceVariant: dark
            ? const Color(0xFFC5D7E4)
            : const Color(0xFF2D4658),
        surfaceContainerLowest: dark
            ? const Color(0xFF071724)
            : const Color(0xFFF8FBFD),
        surfaceContainerLow: dark
            ? const Color(0xFF0D2132)
            : const Color(0xFFF0F6FA),
        surfaceContainer: content,
        surfaceContainerHigh: dark
            ? const Color(0xFF1B394E)
            : const Color(0xFFDAE7F0),
        surfaceContainerHighest: dark
            ? const Color(0xFF284B60)
            : const Color(0xFFCADCE8),
        outline: dark ? const Color(0xFF8AA9BB) : const Color(0xFF617E92),
        outlineVariant: dark
            ? const Color(0xFF36566C)
            : const Color(0xFFA8C1D1),
      );
  final overlay = dark
      ? const Color(0xFF031322).withValues(alpha: 0.08)
      : const Color(0xFFEEF5FA).withValues(alpha: 0.04);
  final readingGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: dark
        ? const [Color(0x40031322), Color(0x10031322), Color(0x08031322)]
        : const [
            Color(0xCCEEF5FA),
            Color(0xBBEEF5FA),
            Color(0x77EEF5FA),
            Color(0x55EEF5FA),
            Color(0x3DEEF5FA),
            Color(0x1AEEF5FA),
          ],
    stops: dark ? const [0, 0.32, 1] : const [0, 0.13, 0.24, 0.43, 0.64, 1],
  );
  return AppSkinBrightnessConfig(
    sheetMotif: AppSkinSheetMotif.starlit,
    colorScheme: scheme,
    colors: AppSkinColors(
      scaffoldBackground: Colors.transparent,
      canvasBackground: Colors.transparent,
      wallpaperFallback: dark
          ? const Color(0xFF071A2B)
          : const Color(0xFFB6CFDF),
      backgroundOverlay: overlay,
      cardBackground: content.withValues(alpha: dark ? 0.68 : 0.76),
      inputBackground: surface.withValues(alpha: 0.88),
      navigationBackground: surface.withValues(alpha: 0.66),
      navigationIndicator: primary.withValues(alpha: 0.16),
      bottomSheetBackground: surface,
      dialogBackground: surface,
      divider: scheme.outlineVariant.withValues(alpha: 0.45),
      snackBarBackground: const Color(0xFF173448),
      fixedControlSurface: surface,
      scrollingContentSurface: content,
      border: scheme.outlineVariant.withValues(alpha: 0.55),
      selectionIndicator: primary,
      shadow: const Color(0xFF03111E),
    ),
    surfaces: AppSkinSurfaces(
      searchOpacity: 0.88,
      miniPlayerOpacity: dark ? 0.74 : 0.82,
      navigationOpacity: dark ? 0.58 : 0.64,
      scrollingContentOpacity: dark ? 0.68 : 0.76,
      bottomSheetOpacity: 1,
    ),
    geometry: const AppSkinGeometry(
      controlRadius: 16,
      cardRadius: 16,
      bottomSheetRadius: 26,
      blurSigma: 10,
      borderWidth: 0.7,
      shadowOpacity: 0.10,
      shadowBlurRadius: 12,
      shadowOffset: Offset(0, 3),
      showNavigationIndicatorPill: true,
    ),
    background: AppSkinBackgroundConfig(
      wallpaper: _image('wallpaper_${dark ? 'dark' : 'light'}.jpg'),
      animation: AppSkinAnimationDescriptor.rive(
        asset: const AppSkinAssetDescriptor(
          path: 'assets/skins/orbital_observatory/ambient.riv',
          type: AppSkinAssetType.rive,
        ),
        artboard: dark ? 'OrbitalNight' : 'OrbitalDay',
        stateMachine: 'AmbientLoop',
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.45),
        opacity: dark ? 0.94 : 0.85,
      ),
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.45),
      overlayColor: overlay,
      readingGradient: readingGradient,
    ),
  );
}
