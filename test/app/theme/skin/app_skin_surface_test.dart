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
  testWidgets('classic surface disables background filtering', (tester) async {
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

    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
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

  testWidgets('wallpaper playback surfaces use tint and one clipped blur', (
    tester,
  ) async {
    final registry = AppSkinRegistry.builtIn(AppThemeAccent.forest);
    for (final skinId in [
      AppSkinRegistry.citySoundCreatorId,
      AppSkinRegistry.starlitMelodyId,
    ]) {
      final skin = registry.resolve(skinId);
      for (final style in AppUiStyle.values) {
        for (final brightness in Brightness.values) {
          for (final role in [
            AppSkinSurfaceRole.miniPlayer,
            AppSkinSurfaceRole.navigation,
            AppSkinSurfaceRole.search,
            AppSkinSurfaceRole.bottomSheet,
          ]) {
            for (final showContentBackground in [false, true]) {
              final config = brightness == Brightness.light
                  ? skin.light
                  : skin.dark;
              final theme = brightness == Brightness.light
                  ? AppTheme.light(
                      skin,
                      uiStyle: style,
                      showContentBackground: showContentBackground,
                    )
                  : AppTheme.dark(
                      skin,
                      uiStyle: style,
                      showContentBackground: showContentBackground,
                    );
              await tester.pumpWidget(
                MaterialApp(
                  theme: theme,
                  home: AppSkinSurface(
                    role: role,
                    showDecoration: false,
                    child: const SizedBox(width: 100, height: 40),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final expectedOpacity = switch (role) {
                AppSkinSurfaceRole.miniPlayer =>
                  config.surfaces.miniPlayerOpacity,
                AppSkinSurfaceRole.navigation =>
                  config.surfaces.navigationOpacity,
                _ => 1.0,
              };
              final decorated = tester.widget<DecoratedBox>(
                find
                    .descendant(
                      of: find.byType(AppSkinSurface),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              );
              expect(
                (decorated.decoration as BoxDecoration).color!.a,
                closeTo(expectedOpacity, 0.001),
              );
              final filters = find.byType(BackdropFilter);
              expect(
                filters,
                expectedOpacity < 1 ? findsOneWidget : findsNothing,
              );
              if (expectedOpacity < 1) {
                expect(
                  find.ancestor(of: filters, matching: find.byType(ClipRRect)),
                  findsOneWidget,
                );
              }
              expect(tester.takeException(), isNull);
            }
          }
        }
      }
    }
  });

  testWidgets('playback skin changes preserve child state and focus', (
    tester,
  ) async {
    final registry = AppSkinRegistry.builtIn(AppThemeAccent.forest);
    final skinId = ValueNotifier(AppSkinRegistry.classicId);
    addTearDown(skinId.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: skinId,
        builder: (context, value, _) => MaterialApp(
          theme: AppTheme.light(registry.resolve(value)),
          home: const Scaffold(
            body: AppSkinSurface(
              role: AppSkinSurfaceRole.miniPlayer,
              child: TextField(),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'keep playback child');
    final element = tester.element(find.byType(TextField));
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    for (final value in [
      AppSkinRegistry.starlitMelodyId,
      AppSkinRegistry.classicId,
    ]) {
      skinId.value = value;
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(TextField)), same(element));
      expect(editable.controller.text, 'keep playback child');
      expect(editable.focusNode.hasFocus, isTrue);
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        value != AppSkinRegistry.classicId,
      );
    }
    expect(tester.takeException(), isNull);
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
