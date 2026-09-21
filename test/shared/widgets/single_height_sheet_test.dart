import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_bottom_sheet.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_bottom_sheet.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/shared/constants/layout_tokens.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  for (final player in [false, true]) {
    testWidgets('medium menu scrolls without resizing: player=$player', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final skin = AppSkinRegistry.builtIn(
        AppThemeAccent.forest,
      ).resolve(AppSkinRegistry.classicId);
      await tester.pumpWidget(
        AppGlassScope(
          enabled: true,
          child: GlassAdaptiveScope(
            minQuality: GlassQuality.minimal,
            maxQuality: GlassQuality.minimal,
            initialQuality: GlassQuality.minimal,
            child: MaterialApp(
              theme: AppTheme.light(skin),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    child: const Text('Open menu'),
                    onPressed: () {
                      Widget content(BuildContext context) => ListView.builder(
                        controller: scroll,
                        itemCount: 40,
                        itemExtent: 48,
                        itemBuilder: (_, index) =>
                            ListTile(title: Text('Action $index')),
                      );
                      if (player) {
                        showPlayerStyledBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: content,
                        );
                      } else {
                        showAppThemedBottomSheet<void>(
                          context: context,
                          heightFactor: 0.60,
                          builder: content,
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();
      final sheet = tester.widget<GlassModalSheet>(
        find.byType(GlassModalSheet),
      );
      expect(sheet.detents, {GlassSheetDetent.medium});
      final fill = find.byKey(const Key('glass_modal_sheet_fill'));
      final top = tester.getTopLeft(fill).dy;
      await tester.drag(find.byType(ListView), const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(100));
      expect(tester.getTopLeft(fill).dy, closeTo(top, 1));
      await tester.dragFrom(Offset(200, top + 14), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.byType(GlassModalSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
    for (final mode in AppGlassMode.values) {
      testWidgets(
        'single-height sheet scrolls immediately and dismisses: player=$player mode=$mode',
        (tester) async {
          tester.view.physicalSize = const Size(400, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          final skin = AppSkinRegistry.builtIn(
            AppThemeAccent.forest,
          ).resolve(AppSkinRegistry.classicId);
          Widget content(BuildContext context) => ListView.builder(
            controller: scroll,
            itemExtent: 48,
            itemCount: 60,
            itemBuilder: (_, index) => ListTile(title: Text('Track $index')),
          );
          await tester.pumpWidget(
            AppGlassScope(
              enabled: mode != AppGlassMode.off,
              mode: mode,
              child: GlassAdaptiveScope(
                minQuality: GlassQuality.minimal,
                maxQuality: GlassQuality.minimal,
                initialQuality: GlassQuality.minimal,
                child: MaterialApp(
                  theme: AppTheme.light(skin),
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () {
                          if (player) {
                            showPlayerStyledBottomSheet<void>(
                              context: context,
                              fixedHeightFactor:
                                  LayoutTokens.queueSheetHeightFactor,
                              builder: content,
                            );
                          } else {
                            showAppThemedBottomSheet<void>(
                              context: context,
                              fixedHeightFactor:
                                  LayoutTokens.queueSheetHeightFactor,
                              builder: content,
                            );
                          }
                        },
                        child: const Text('Open queue'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open queue'));
          await tester.pumpAndSettle();
          final usesGlass = mode.usesGlass;
          final surface = usesGlass
              ? find.byKey(const Key('glass_modal_sheet_fill'))
              : find.byType(BottomSheet);
          var initialTop = tester.getTopLeft(surface).dy;
          expect(tester.getSize(surface).height, closeTo(800 * 0.88, 16));
          if (usesGlass) {
            final sheet = tester.widget<GlassModalSheet>(
              find.byType(GlassModalSheet),
            );
            expect(sheet.detents, {GlassSheetDetent.medium});
            expect(sheet.halfSize, LayoutTokens.queueSheetHeightFactor);
            expect(
              (tester.widget<DecoratedBox>(surface).decoration as BoxDecoration)
                  .color!
                  .a,
              0,
            );
            expect(find.byType(PlayerSheetSurface), findsNothing);
          } else {
            expect(find.byType(GlassModalSheet), findsNothing);
            expect(find.byType(BackdropFilter), findsNothing);
          }
          if (player && !usesGlass) {
            final fill = tester.widget<ColoredBox>(
              find.descendant(
                of: find.byType(PlayerSheetSurface),
                matching: find.byType(ColoredBox),
              ),
            );
            expect(fill.color.a, 1);
          } else if (!player && !usesGlass) {
            expect(tester.widget<BottomSheet>(surface).backgroundColor!.a, 1);
          }
          await tester.drag(find.byType(ListView), const Offset(0, -250));
          await tester.pumpAndSettle();
          expect(scroll.offset, greaterThan(100));
          expect(tester.getTopLeft(surface).dy, closeTo(initialTop, 1));
          // Resizing an already-open sheet must recompute its single height.
          tester.view.physicalSize = const Size(400, 600);
          await tester.pumpAndSettle();
          expect(tester.getSize(surface).height, closeTo(600 * 0.88, 16));
          if (usesGlass) {
            expect(
              (tester.widget<DecoratedBox>(surface).decoration as BoxDecoration)
                  .color!
                  .a,
              0,
              reason:
                  'Resizing must not turn a single-detent glass sheet opaque.',
            );
          }
          initialTop = tester.getTopLeft(surface).dy;
          scroll.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.dragFrom(
            Offset(200, initialTop + 14),
            const Offset(0, 650),
          );
          await tester.pumpAndSettle();
          expect(find.byType(ListView), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
