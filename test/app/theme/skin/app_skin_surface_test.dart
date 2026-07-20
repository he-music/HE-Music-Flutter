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

  testWidgets('surface roles use their configured skin radius', (tester) async {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.citySoundCreatorId);

    Future<BorderRadiusGeometry?> renderRadius(AppSkinSurfaceRole role) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(skin),
          home: AppSkinSurface(
            role: role,
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      );
      final decoratedBox = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppSkinSurface),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      return (decoratedBox.decoration as BoxDecoration).borderRadius;
    }

    expect(
      await renderRadius(AppSkinSurfaceRole.scrollingContent),
      BorderRadius.circular(skin.light.geometry.cardRadius),
    );
    expect(
      await renderRadius(AppSkinSurfaceRole.bottomSheet),
      BorderRadius.circular(skin.light.geometry.bottomSheetRadius),
    );
  });

  testWidgets('surface shadow uses configured skin geometry', (tester) async {
    final base = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.citySoundCreatorId);
    final skin = base.copyWith(
      light: base.light.copyWith(
        geometry: base.light.geometry.copyWith(
          shadowBlurRadius: 7,
          shadowOffset: const Offset(2, 3),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(skin),
        home: const AppSkinSurface(
          role: AppSkinSurfaceRole.search,
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppSkinSurface),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final shadow = (decoratedBox.decoration as BoxDecoration).boxShadow!.single;
    expect(shadow.blurRadius, 7);
    expect(shadow.offset, const Offset(2, 3));
  });

  testWidgets('transparent surface does not draw a shadow', (tester) async {
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

    final decoratedBox = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppSkinSurface),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((decoratedBox.decoration as BoxDecoration).boxShadow, isEmpty);
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

  test(
    'transparent scrolling surfaces delegate readability to the overlay',
    () {
      final skin = AppSkinRegistry.builtIn(
        AppThemeAccent.forest,
      ).resolve(AppSkinRegistry.citySoundCreatorId);

      for (final config in <AppSkinBrightnessConfig>[skin.light, skin.dark]) {
        expect(config.surfaces.scrollingContentOpacity, 0);
        expect(config.colors.cardBackground.a, 0);
        expect(config.colors.backgroundOverlay, config.background.overlayColor);
      }

      expect(skin.light.background.overlayColor, const Color(0x7AFFFFFF));
      expect(skin.dark.background.overlayColor, const Color(0x42111615));
    },
  );
}
