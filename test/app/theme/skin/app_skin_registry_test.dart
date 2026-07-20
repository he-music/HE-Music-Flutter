import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skins/classic_skin.dart';

void main() {
  test('built-in registry resolves classic and city skin', () {
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
      AppSkinRegistry.builtIn(
        AppThemeAccent.forest,
      ).resolve('city_sound_creator').light.colorScheme.primary,
      AppSkinRegistry.builtIn(
        AppThemeAccent.rose,
      ).resolve('city_sound_creator').light.colorScheme.primary,
    );
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
