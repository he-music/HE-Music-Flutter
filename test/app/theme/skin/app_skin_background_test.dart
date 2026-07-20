import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_asset_resolver.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_background.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_rive_animation.dart';
import 'package:he_music_flutter/app/theme/skins/classic_skin.dart';

void main() {
  testWidgets('background selects the current light and dark fallback', (
    tester,
  ) async {
    final classic = classicSkinForAccent(AppThemeAccent.forest);
    var mode = ThemeMode.light;

    Future<void> pump() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(classic),
          darkTheme: AppTheme.dark(classic),
          themeMode: mode,
          home: AppSkinBackgroundLayer(skin: classic, enableAnimation: true),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump();
    expect(_fallbackColor(tester), classic.light.colors.wallpaperFallback);

    mode = ThemeMode.dark;
    await pump();
    expect(_fallbackColor(tester), classic.dark.colors.wallpaperFallback);
  });

  testWidgets('background does not block taps or expose semantics', (
    tester,
  ) async {
    final classic = classicSkinForAccent(AppThemeAccent.forest);
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(classic),
        home: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AppSkinBackgroundLayer(skin: classic, enableAnimation: true),
            Center(
              child: FilledButton(
                onPressed: () => taps += 1,
                child: const Text('Tap'),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Tap'));
    expect(taps, 1);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('app-skin-background')),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
  });

  testWidgets('asset failure keeps the fallback instead of an empty page', (
    tester,
  ) async {
    final classic = classicSkinForAccent(AppThemeAccent.forest);
    final withWallpaper = classic.copyWith(
      light: classic.light.copyWith(
        background: classic.light.background.copyWith(
          wallpaper: const AppSkinAssetSlot.asset(
            AppSkinAssetDescriptor(
              path: 'assets/skins/test/missing.png',
              type: AppSkinAssetType.rasterImage,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(withWallpaper),
        home: AppSkinBackgroundLayer(
          skin: withWallpaper,
          enableAnimation: true,
          assetResolver: const _FailingResolver(),
        ),
      ),
    );
    await tester.pump();

    expect(_fallbackColor(tester), classic.light.colors.wallpaperFallback);
    expect(
      find.byKey(const ValueKey<String>('app-skin-wallpaper')),
      findsNothing,
    );
  });

  testWidgets('background rebuild reuses the loaded image provider', (
    tester,
  ) async {
    final classic = classicSkinForAccent(AppThemeAccent.forest);
    final withWallpaper = classic.copyWith(
      light: classic.light.copyWith(
        background: classic.light.background.copyWith(
          wallpaper: const AppSkinAssetSlot.asset(
            AppSkinAssetDescriptor(
              path: 'assets/skins/test/wallpaper.png',
              type: AppSkinAssetType.rasterImage,
            ),
          ),
        ),
      ),
    );
    final resolver = _CountingResolver();

    Future<void> pumpBackground() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(withWallpaper),
          home: AppSkinBackgroundLayer(
            skin: withWallpaper,
            enableAnimation: true,
            assetResolver: resolver,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpBackground();
    final firstProvider = tester
        .widget<Image>(find.byKey(const ValueKey<String>('app-skin-wallpaper')))
        .image;

    await pumpBackground();
    final secondProvider = tester
        .widget<Image>(find.byKey(const ValueKey<String>('app-skin-wallpaper')))
        .image;

    expect(resolver.loadCount, 1);
    expect(identical(secondProvider, firstProvider), isTrue);
  });

  testWidgets('transparent skins suppress legacy page decoration', (
    tester,
  ) async {
    final immersive = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.citySoundCreatorId);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(immersive),
        home: const AppSkinLegacyPageBackground(
          child: ColoredBox(
            key: ValueKey<String>('legacy-page-decoration'),
            color: Colors.red,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('legacy-page-decoration')),
      findsNothing,
    );
  });

  testWidgets('readability overlay is rendered below the Rive animation', (
    tester,
  ) async {
    final immersive = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.citySoundCreatorId);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(immersive),
        home: AppSkinBackgroundLayer(
          skin: immersive,
          enableAnimation: false,
          assetResolver: const _FailingResolver(),
        ),
      ),
    );
    await tester.pump();

    final stack = tester.widget<Stack>(
      find.byKey(const ValueKey<String>('app-skin-background')),
    );
    final overlayIndex = stack.children.indexWhere(
      (child) =>
          child.key == const ValueKey<String>('app-skin-background-overlay'),
    );
    final riveIndex = stack.children.indexWhere(
      (child) => child is AppSkinRiveAnimation,
    );
    expect(overlayIndex, greaterThanOrEqualTo(0));
    expect(riveIndex, greaterThan(overlayIndex));
  });
}

Color _fallbackColor(WidgetTester tester) {
  return tester
      .widget<ColoredBox>(
        find.byKey(const ValueKey<String>('app-skin-background-fallback')),
      )
      .color;
}

class _FailingResolver implements AppSkinAssetResolver {
  const _FailingResolver();

  @override
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor) async {
    return AppSkinAssetLoadFailure(StateError('missing'));
  }
}

class _CountingResolver implements AppSkinAssetResolver {
  static final _pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
    'AQUBAScY42YAAAAASUVORK5CYII=',
  );

  var loadCount = 0;

  @override
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor) async {
    loadCount += 1;
    return AppSkinAssetLoadSuccess(_pngBytes.buffer.asByteData());
  }
}
