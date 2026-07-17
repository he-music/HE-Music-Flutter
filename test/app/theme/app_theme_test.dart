import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_theme.dart';

void main() {
  test('light theme uses dark status bar icons', () {
    final overlayStyle = AppTheme.systemOverlayStyleForBrightness(
      Brightness.light,
    );
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.cobalt,
    ).resolve('classic');
    final theme = AppTheme.light(skin);

    expect(overlayStyle.statusBarIconBrightness, Brightness.dark);
    expect(theme.appBarTheme.systemOverlayStyle, overlayStyle);
    expect(overlayStyle.statusBarBrightness, Brightness.light);
    expect(overlayStyle.statusBarColor, Colors.transparent);
  });

  test('dark theme uses light status bar icons', () {
    final overlayStyle = AppTheme.systemOverlayStyleForBrightness(
      Brightness.dark,
    );
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.cobalt,
    ).resolve('classic');
    final theme = AppTheme.dark(skin);

    expect(overlayStyle.statusBarIconBrightness, Brightness.light);
    expect(theme.appBarTheme.systemOverlayStyle, overlayStyle);
    expect(overlayStyle.statusBarBrightness, Brightness.dark);
    expect(overlayStyle.statusBarColor, Colors.transparent);
  });

  test('immersive themes use transparent Android route transitions', () {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.rose,
    ).resolve(AppSkinRegistry.citySoundCreatorId);

    final lightTheme = AppTheme.light(skin);
    final darkTheme = AppTheme.dark(skin);

    expect(lightTheme.extension<AppSkinTheme>()?.config, skin.light);
    expect(darkTheme.extension<AppSkinTheme>()?.config, skin.dark);
    for (final theme in <ThemeData>[lightTheme, darkTheme]) {
      expect(theme.scaffoldBackgroundColor, Colors.transparent);
      expect(theme.navigationBarTheme.indicatorColor, Colors.transparent);
      final androidTransition =
          theme.pageTransitionsTheme.builders[TargetPlatform.android];
      expect(androidTransition, isA<FadeForwardsPageTransitionsBuilder>());
      expect(
        (androidTransition! as FadeForwardsPageTransitionsBuilder)
            .backgroundColor,
        Colors.transparent,
      );
    }
  });

  test('classic keeps its existing dialog and navigation surfaces', () {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.cobalt,
    ).resolve(AppSkinRegistry.classicId);

    final theme = AppTheme.light(skin);

    expect(
      theme.dialogTheme.backgroundColor,
      theme.colorScheme.surfaceContainerHigh,
    );
    expect(
      theme.navigationBarTheme.indicatorColor,
      theme.colorScheme.primaryContainer,
    );
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<PredictiveBackPageTransitionsBuilder>(),
    );
  });
}
