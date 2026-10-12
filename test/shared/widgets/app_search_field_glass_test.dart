import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/app/theme/skins/starlit_melody_skin.dart';
import 'package:he_music_flutter/features/home/presentation/widgets/home_search_field.dart';
import 'package:he_music_flutter/shared/widgets/app_search_field.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final quality in [GlassQuality.standard, GlassQuality.minimal]) {
      testWidgets(
        '$brightness search glass remains visible and translucent at $quality',
        (tester) async {
          final controller = TextEditingController();
          addTearDown(controller.dispose);
          final skin = starlitMelodySkin();
          final theme = brightness == Brightness.light
              ? AppTheme.light(skin)
              : AppTheme.dark(skin);
          final backdrop = brightness == Brightness.light
              ? const Color(0xFF9DD9F2)
              : const Color(0xFF101C2B);
          final captureKey = GlobalKey();
          var taps = 0;
          await tester.runAsync(() async {
            await LiquidGlassWidgets.initialize(
              enablePerformanceMonitor: false,
              warmUpMode: GlassWarmUpMode.never,
            );
          });
          await tester.pumpWidget(
            LiquidGlassWidgets.wrap(
              adaptiveQuality: false,
              brightnessResolver: Theme.maybeBrightnessOf,
              child: AppGlassScope(
                enabled: true,
                mode: AppGlassMode.high,
                child: GlassAdaptiveScope(
                  minQuality: quality,
                  maxQuality: quality,
                  child: MaterialApp(
                    theme: theme,
                    home: GlassScaffold(
                      body: Center(
                        child: RepaintBoundary(
                          key: captureKey,
                          child: SizedBox(
                            width: 360,
                            height: 160,
                            child: ColoredBox(
                              color: backdrop,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    HomeSearchField(
                                      placeholderPrimary: '搜索',
                                      onTap: () => taps++,
                                    ),
                                    const SizedBox(height: 16),
                                    AppSearchField(
                                      controller: controller,
                                      placeholderPrimary: '搜索',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final input = tester.widget<GlassTextField>(
            find.byType(GlassTextField),
          );
          final button = tester.widget<GlassButton>(find.byType(GlassButton));
          for (final settings in [input.settings!, button.settings!]) {
            expect(settings.bodyMode, GlassBodyMode.clear);
            expect(settings.glassColor.a, inExclusiveRange(0, 1));
            expect(settings.blur, greaterThan(0));
          }
          expect(input.quality, GlassQuality.standard);
          expect(button.quality, GlassQuality.standard);

          final origin = tester.getTopLeft(find.byKey(captureKey));
          final samples =
              [find.byType(HomeSearchField), find.byType(AppSearchField)].map((
                finder,
              ) {
                final rect = tester.getRect(finder);
                return Offset(rect.right - 60, rect.center.dy) - origin;
              }).toList();
          final boundary =
              captureKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              final expected = Color.alphaBlend(
                input.settings!.glassColor,
                backdrop,
              );
              for (final point in samples) {
                final offset =
                    (point.dy.round() * image.width + point.dx.round()) * 4;
                final actual = Color.fromARGB(
                  bytes.getUint8(offset + 3),
                  bytes.getUint8(offset),
                  bytes.getUint8(offset + 1),
                  bytes.getUint8(offset + 2),
                );
                for (final channel in [
                  (actual.r, expected.r),
                  (actual.g, expected.g),
                  (actual.b, expected.b),
                ]) {
                  expect(channel.$1, closeTo(channel.$2, 0.06));
                }
                expect(
                  (actual.computeLuminance() - backdrop.computeLuminance())
                      .abs(),
                  greaterThan(brightness == Brightness.dark ? 0.01 : 0.025),
                );
              }
              if (const bool.fromEnvironment('CAPTURE_SEARCH_PREVIEWS')) {
                final png = (await image.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!;
                await File(
                  '/tmp/he-music-search-glass-${brightness.name}-${quality.name}.png',
                ).writeAsBytes(png.buffer.asUint8List());
              }
            } finally {
              image.dispose();
            }
          });

          await tester.tap(find.byType(HomeSearchField));
          await tester.pumpAndSettle();
          expect(taps, 1);
          await tester.enterText(find.byType(EditableText), '周杰伦');
          await tester.pump();
          expect(controller.text, '周杰伦');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
