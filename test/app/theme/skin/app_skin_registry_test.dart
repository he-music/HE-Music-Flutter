import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_custom_skin_config.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skins/classic_skin.dart';

void main() {
  test('built-in registry resolves classic, city, and starlit skins', () {
    final registry = AppSkinRegistry.builtIn(AppThemeAccent.cobalt);

    expect(
      registry.skins.map((skin) => skin.metadata.id).toSet(),
      AppSkinRegistry.builtInIds,
    );
    expect(registry.resolve('classic').metadata.id, 'classic');
    expect(
      registry.resolve('city_sound_creator').metadata.id,
      'city_sound_creator',
    );
    expect(registry.resolve('starlit_melody').metadata.id, 'starlit_melody');
    expect(registry.resolve('missing').metadata.id, 'classic');
  });

  test('classic keeps the selected manual accent', () {
    final forest = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve('classic');
    final rose = AppSkinRegistry.builtIn(
      AppThemeAccent.rose,
    ).resolve('classic');

    expect(
      forest.light.colorScheme.primary,
      isNot(rose.light.colorScheme.primary),
    );
    expect(
      forest.metadata.lightPreview.descriptor?.path,
      'assets/skins/classic/preview_light.png',
    );
    expect(
      forest.metadata.darkPreview.descriptor?.path,
      'assets/skins/classic/preview_dark.png',
    );
    expect(
      AppSkinRegistry.builtIn(
        AppThemeAccent.forest,
      ).resolve('city_sound_creator').light.colorScheme.primary,
      AppSkinRegistry.builtIn(
        AppThemeAccent.rose,
      ).resolve('city_sound_creator').light.colorScheme.primary,
    );
    expect(
      AppSkinRegistry.builtIn(
        AppThemeAccent.forest,
      ).resolve('starlit_melody').light.colorScheme.primary,
      AppSkinRegistry.builtIn(
        AppThemeAccent.rose,
      ).resolve('starlit_melody').light.colorScheme.primary,
    );
  });

  test('custom image skin is registered only when config is available', () {
    final builtIn = AppSkinRegistry.withCustom(AppThemeAccent.forest, null);
    final withCustom = AppSkinRegistry.withCustom(
      AppThemeAccent.forest,
      _customConfig(),
    );
    final custom = withCustom.resolve(AppSkinRegistry.customImageId);

    expect(builtIn.contains(AppSkinRegistry.customImageId), isFalse);
    expect(withCustom.skins, hasLength(4));
    expect(custom.metadata.source, AppSkinSource.userGenerated);
    expect(custom.metadata.allowsManualAccent, isFalse);
    expect(
      custom.light.background.wallpaper.descriptor?.source,
      AppSkinAssetSource.applicationSupport,
    );
    expect(custom.light.background.alignment, const Alignment(0.2, -0.3));
    expect(custom.light.background.overlayColor, Colors.transparent);
    expect(custom.dark.background.overlayColor, Colors.transparent);
    expect(
      custom.light.background.animation,
      isA<AppSkinNoAnimationDescriptor>(),
    );
    expect(custom.icons, classicSkinForAccent(AppThemeAccent.graphite).icons);
    expect(custom.light.colorScheme.brightness, Brightness.light);
    expect(custom.dark.colorScheme.brightness, Brightness.dark);
    expect(custom.light.surfaces.scrollingContentOpacity, 0);
    expect(custom.dark.surfaces.scrollingContentOpacity, 0);
    expect(custom.light.colors.cardBackground.a, 0);
    expect(custom.dark.colors.cardBackground.a, 0);
  });

  test('starlit evaluation skin customizes light and dark appearance', () {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.cobalt,
    ).resolve('starlit_melody');
    final graphite = classicSkinForAccent(AppThemeAccent.graphite);

    expect(skin.metadata.allowsManualAccent, isFalse);
    expect(
      skin.metadata.lightPreview.descriptor?.path,
      'assets/skins/starlit_melody/preview_light.png',
    );
    expect(
      skin.metadata.darkPreview.descriptor?.path,
      'assets/skins/starlit_melody/preview_dark.png',
    );
    expect(
      skin.light.background.wallpaper.descriptor?.path,
      'assets/skins/starlit_melody/wallpaper_light.png',
    );
    expect(
      skin.light.background.animation,
      const AppSkinNoAnimationDescriptor(),
    );
    expect(skin.light.colorScheme.primary, const Color(0xFF00677A));
    expect(skin.light.colorScheme.secondary, const Color(0xFFB72F5B));
    expect(skin.light.colorScheme.tertiary, const Color(0xFF735C00));
    expect(skin.light.colorScheme.onSurface, const Color(0xFF17202A));
    expect(skin.light.colorScheme.onSurfaceVariant, const Color(0xFF46515C));
    expect(skin.light.surfaces.scrollingContentOpacity, 0);
    expect(skin.light.colors.cardBackground.a, 0);
    expect(
      skin.dark.background.wallpaper.descriptor?.path,
      'assets/skins/starlit_melody/wallpaper_dark_evaluation.png',
    );
    expect(
      skin.dark.background.animation,
      const AppSkinNoAnimationDescriptor(),
    );
    expect(skin.dark.colorScheme.primary, const Color(0xFF78D5E7));
    expect(skin.dark.colorScheme.secondary, const Color(0xFFFFB0C8));
    expect(skin.dark.colorScheme.tertiary, const Color(0xFFF2CE67));
    expect(skin.dark.colorScheme.onSurface, const Color(0xFFF0EDF5));
    expect(skin.dark.colorScheme.onSurfaceVariant, const Color(0xFFD3CBD7));
    expect(skin.dark.colorScheme.surface, const Color(0xFF213A4C));
    expect(
      skin.dark.colorScheme.surfaceContainerHighest,
      const Color(0xFF355A70),
    );
    expect(skin.dark.colors.fixedControlSurface, const Color(0xFF294A61));
    expect(skin.dark.colors.inputBackground, const Color(0xC2294A61));
    expect(skin.dark.colors.navigationBackground, const Color(0xD1294A61));
    expect(skin.dark.surfaces.searchOpacity, 0.76);
    expect(skin.dark.surfaces.miniPlayerOpacity, 0.78);
    expect(skin.dark.surfaces.navigationOpacity, 0.82);
    expect(skin.dark.surfaces.scrollingContentOpacity, 0);
    expect(skin.dark.colors.cardBackground.a, 0);
    expect(
      skin.dark.colors.backgroundOverlay,
      skin.dark.background.overlayColor,
    );
    expect(skin.dark.background.fit, skin.light.background.fit);
    expect(skin.dark.background.alignment, skin.light.background.alignment);
    expect(skin.dark, isNot(graphite.dark));
    expect(skin.icons, graphite.icons);
  });

  test('registry rejects duplicate ids', () {
    final classic = classicSkinForAccent(AppThemeAccent.forest);

    expect(
      () => AppSkinRegistry(<AppSkinPackage>[classic, classic]),
      throwsStateError,
    );
  });

  test('registry rejects invalid surface values', () {
    final classic = classicSkinForAccent(AppThemeAccent.forest);
    final invalid = classic.copyWith(
      light: classic.light.copyWith(
        surfaces: classic.light.surfaces.copyWith(searchOpacity: 1.1),
      ),
    );

    expect(() => AppSkinRegistry(<AppSkinPackage>[invalid]), throwsStateError);
  });

  test('registry rejects non-finite geometry values', () {
    final classic = classicSkinForAccent(AppThemeAccent.forest);
    final invalidBlur = classic.copyWith(
      light: classic.light.copyWith(
        geometry: classic.light.geometry.copyWith(blurSigma: double.infinity),
      ),
    );
    final invalidShadow = classic.copyWith(
      light: classic.light.copyWith(
        geometry: classic.light.geometry.copyWith(
          shadowBlurRadius: -1,
          shadowOffset: const Offset(double.nan, 0),
        ),
      ),
    );

    expect(
      () => AppSkinRegistry(<AppSkinPackage>[invalidBlur]),
      throwsStateError,
    );
    expect(
      () => AppSkinRegistry(<AppSkinPackage>[invalidShadow]),
      throwsStateError,
    );
  });

  test('registry rejects incomplete icon catalogs', () {
    final classic = classicSkinForAccent(AppThemeAccent.forest);
    final values = Map<AppSkinIconRole, AppSkinIconSpec>.of(
      classic.icons.values,
    )..remove(AppSkinIconRole.search);
    final invalid = classic.copyWith(icons: AppSkinIconCatalog(values));

    expect(() => AppSkinRegistry(<AppSkinPackage>[invalid]), throwsStateError);
  });

  test('registry rejects unresolved slots in classic', () {
    final classic = classicSkinForAccent(AppThemeAccent.forest);
    final invalid = classic.copyWith(
      light: classic.light.copyWith(
        background: classic.light.background.copyWith(
          wallpaper: const AppSkinAssetSlot.inherit(),
        ),
      ),
    );

    expect(() => AppSkinRegistry(<AppSkinPackage>[invalid]), throwsStateError);
  });

  test('copied skin resolves inherited wallpaper against classic', () {
    final classic = classicSkinForAccent(AppThemeAccent.forest);
    final copied = classic.copyWith(
      metadata: classic.metadata.copyWith(id: 'copied_skin'),
      light: classic.light.copyWith(
        background: classic.light.background.copyWith(
          wallpaper: const AppSkinAssetSlot.inherit(),
        ),
      ),
    );

    final resolved = AppSkinRegistry(<AppSkinPackage>[
      classic,
      copied,
    ]).resolve('copied_skin');

    expect(resolved.light.background.wallpaper.isResolved, isTrue);
    expect(resolved.light.background.wallpaper.kind, AppSkinAssetSlotKind.none);
  });

  test('theme extension models support value equality and interpolation', () {
    final classic = classicSkinForAccent(AppThemeAccent.forest);

    expect(classic.light.colors.copyWith(), classic.light.colors);
    expect(classic.light.surfaces.copyWith(), classic.light.surfaces);
    expect(classic.light.geometry.copyWith(), classic.light.geometry);
    expect(
      const AppSkinAssetDescriptor(
        path: 'assets/skins/test/icon.svg',
        type: AppSkinAssetType.svg,
      ).copyWith(),
      const AppSkinAssetDescriptor(
        path: 'assets/skins/test/icon.svg',
        type: AppSkinAssetType.svg,
      ),
    );
    expect(
      classic.icons[AppSkinIconRole.search]!.copyWith(),
      classic.icons[AppSkinIconRole.search],
    );
    expect(
      classic.light.background.wallpaper.copyWith(),
      classic.light.background.wallpaper,
    );
    expect(
      const AppSkinNoAnimationDescriptor().copyWith(),
      const AppSkinNoAnimationDescriptor(),
    );
    expect(
      AppSkinBrightnessConfig.lerp(classic.light, classic.light, 0.5),
      classic.light,
    );
    expect(classic.light.colorScheme.brightness, Brightness.light);
  });
}

AppCustomSkinConfig _customConfig() {
  return AppCustomSkinConfig(
    revision: 'revision_1',
    lightAssetPath: 'skins/custom_image/revision_1/wallpaper_light.jpg',
    darkAssetPath: 'skins/custom_image/revision_1/wallpaper_dark.jpg',
    candidateColors: const <int>[0xFF336699],
    seedColor: 0xFF336699,
    focalX: 0.2,
    focalY: -0.3,
    sourceWidth: 1200,
    sourceHeight: 1600,
  );
}
