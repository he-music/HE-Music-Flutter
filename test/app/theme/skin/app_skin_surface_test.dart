import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
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

  for (final style in AppUiStyle.values) {
    testWidgets('wallpaper content retains its reading surface in $style', (
      tester,
    ) async {
      final skin = AppSkinRegistry.builtIn(
        AppThemeAccent.forest,
      ).resolve(AppSkinRegistry.citySoundCreatorId);
      const capture = ValueKey('reading-surface-capture');
      for (final enabled in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(
              skin,
              uiStyle: style,
              showContentBackground: enabled,
            ),
            home: const Center(
              child: RepaintBoundary(
                key: capture,
                child: SizedBox(
                  width: 100,
                  height: 40,
                  child: ColoredBox(
                    color: Colors.black,
                    child: AppSkinSurface(
                      role: AppSkinSurfaceRole.scrollingContent,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final pixels = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final red = pixels!.getUint8(4 * (20 * 100 + 50));
            expect(red, enabled ? greaterThan(140) : 0);
          } finally {
            image.dispose();
          }
        });
      }
    });
  }

  testWidgets('immersive fixed controls stay opaque without background blur', (
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

    expect(find.byType(BackdropFilter), findsNothing);
    final surface = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    expect((surface.decoration as BoxDecoration).color!.a, 1);
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
    expect((decoratedBox.decoration as BoxDecoration).border, isNull);
    expect((decoratedBox.decoration as BoxDecoration).gradient, isNull);
  });

  testWidgets('content surface follows preference for classic and immersive', (
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
        theme: AppTheme.light(classic, showContentBackground: true),
        home: const AppSkinContentSurface(
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppSkinSurface), findsOneWidget);

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
    var decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(AppSkinSurface),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.color?.a, 0);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(immersive, showContentBackground: true),
        home: const AppSkinContentSurface(
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );
    await tester.pumpAndSettle();
    decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(AppSkinSurface),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.color?.a, 0.6);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  test('city skin owns enabled content surface styles', () {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.citySoundCreatorId);

    for (final config in <AppSkinBrightnessConfig>[skin.light, skin.dark]) {
      final expectedOpacity = config.colorScheme.brightness == Brightness.light
          ? 0.6
          : 0.62;
      expect(config.surfaces.scrollingContentOpacity, expectedOpacity);
      expect(config.colors.cardBackground.a, expectedOpacity);
      expect(config.colors.backgroundOverlay, config.background.overlayColor);
    }

    expect(skin.light.background.overlayColor, const Color(0x7AFFFFFF));
    expect(skin.dark.background.overlayColor, const Color(0x42111615));
  });
}
