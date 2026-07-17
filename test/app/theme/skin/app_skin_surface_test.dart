import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_surface.dart';

void main() {
  testWidgets('classic surface skips BackdropFilter when blur is zero', (
    tester,
  ) async {
    final classic = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.classicId);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(classic),
        home: const AppSkinSurface(
          role: AppSkinSurfaceRole.miniPlayer,
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('immersive fixed surface applies configured blur', (
    tester,
  ) async {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.citySoundCreatorId);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(skin),
        home: const AppSkinSurface(
          role: AppSkinSurfaceRole.navigation,
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('scrolling surface never creates a BackdropFilter', (
    tester,
  ) async {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.citySoundCreatorId);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(skin),
        home: const AppSkinSurface(
          role: AppSkinSurfaceRole.scrollingContent,
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('content surface is enabled only when wallpaper is visible', (
    tester,
  ) async {
    final registry = AppSkinRegistry.builtIn(AppThemeAccent.forest);
    final classic = registry.resolve(AppSkinRegistry.classicId);
    final immersive = registry.resolve(AppSkinRegistry.citySoundCreatorId);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(classic),
        home: const AppSkinContentSurface(
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );
    expect(find.byType(AppSkinSurface), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(immersive),
        home: const AppSkinContentSurface(
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppSkinSurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  test('scrolling surfaces keep text contrast on light and dark backdrops', () {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.citySoundCreatorId);

    for (final config in <AppSkinBrightnessConfig>[skin.light, skin.dark]) {
      final surface = config.colors.scrollingContentSurface;
      final opacity = config.surfaces.scrollingContentOpacity;
      final foregrounds = <Color>[
        config.colorScheme.onSurface,
        config.colorScheme.onSurfaceVariant,
      ];
      for (final backdrop in const <Color>[Colors.black, Colors.white]) {
        final background = Color.alphaBlend(
          surface.withValues(alpha: surface.a * opacity),
          backdrop,
        );
        for (final foreground in foregrounds) {
          expect(
            _contrastRatio(foreground, background),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    }
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
