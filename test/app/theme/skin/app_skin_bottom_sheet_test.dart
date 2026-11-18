import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_bottom_sheet.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_bottom_sheet_surface.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_theme.dart';

void main() {
  testWidgets('themed bottom sheet preserves typed result and surface', (
    tester,
  ) async {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.forest,
    ).resolve(AppSkinRegistry.citySoundCreatorId);
    int? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(skin),
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showAppThemedBottomSheet<int>(
                context: context,
                builder: (sheetContext) => TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(7),
                  child: const Text('Close'),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(
      bottomSheet.backgroundColor,
      skin.light.colors.bottomSheetBackground.withValues(alpha: 1),
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(result, 7);
  });
  testWidgets(
    'changing only the sheet motif repaints artwork and preserves input',
    (tester) async {
      final motif = ValueNotifier(AppSkinSheetMotif.starlit);
      addTearDown(motif.dispose);
      final skin = AppSkinRegistry.builtIn(
        AppThemeAccent.forest,
      ).resolve(AppSkinRegistry.starlitMelodyId);
      final base = AppTheme.light(skin);
      final skinTheme = base.extension<AppSkinTheme>()!;
      await tester.pumpWidget(
        ValueListenableBuilder<AppSkinSheetMotif>(
          valueListenable: motif,
          builder: (context, value, child) => MaterialApp(
            theme: base.copyWith(
              extensions: [
                for (final extension in base.extensions.values)
                  if (extension is! AppSkinTheme) extension,
                skinTheme.copyWith(
                  config: skinTheme.config.copyWith(sheetMotif: value),
                ),
              ],
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showAppThemedBottomSheet<void>(
                    context: context,
                    builder: (_) => const Padding(
                      padding: EdgeInsets.all(16),
                      child: TextField(key: ValueKey('skin-sheet-input')),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('skin-sheet-input')),
        'Keep my draft',
      );
      final fieldState = tester.state(find.byType(TextField));
      final route = ModalRoute.of(tester.element(find.byType(TextField)));
      final decoration = tester.renderObject<RenderRepaintBoundary>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('app-skin-sheet-decoration')),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );
      final layer = decoration.debugLayer! as OffsetLayer;
      final picture = (layer.firstChild! as PictureLayer).picture;
      expect(picture, isNotNull);
      motif.value = AppSkinSheetMotif.urban;
      await tester.pumpAndSettle();
      expect(
        Theme.of(
          tester.element(find.byType(AppSkinBottomSheetSurface)),
        ).extension<AppSkinTheme>()!.config.sheetMotif,
        AppSkinSheetMotif.urban,
      );
      expect((layer.firstChild! as PictureLayer).picture, isNot(same(picture)));
      expect(tester.state(find.byType(TextField)), same(fieldState));
      expect(
        ModalRoute.of(tester.element(find.byType(TextField))),
        same(route),
      );
      expect(find.text('Keep my draft'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final skinId in [
    AppSkinRegistry.forestSanctuaryId,
    AppSkinRegistry.tidalSanctuaryId,
    AppSkinRegistry.starlitMelodyId,
    AppSkinRegistry.citySoundCreatorId,
  ]) {
    for (final style in AppUiStyle.values) {
      for (final brightness in Brightness.values) {
        testWidgets(
          '$skinId ${style.name} ${brightness.name} sheet scrolls and returns selection',
          (tester) async {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final skin = AppSkinRegistry.builtIn(
              AppThemeAccent.forest,
            ).resolve(skinId);
            int? result;
            await tester.pumpWidget(
              MaterialApp(
                theme: brightness == Brightness.light
                    ? AppTheme.light(skin, uiStyle: style)
                    : AppTheme.dark(skin, uiStyle: style),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        result = await showAppThemedBottomSheet<int>(
                          context: context,
                          fitContent: true,
                          heightFactor: 0.7,
                          builder: (sheetContext) => ListView.builder(
                            shrinkWrap: true,
                            itemCount: 80,
                            itemBuilder: (context, index) => ListTile(
                              title: Text('Item $index'),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(index),
                            ),
                          ),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
            expect(find.byType(AppSkinBottomSheetSurface), findsOneWidget);
            final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
            expect(sheet.showDragHandle, isTrue);
            expect(sheet.clipBehavior, Clip.antiAlias);
            final decoration = tester.renderObject<RenderRepaintBoundary>(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('app-skin-sheet-decoration')),
                    matching: find.byType(RepaintBoundary),
                  )
                  .first,
            );
            final layer = decoration.debugLayer! as OffsetLayer;
            final picture = (layer.firstChild! as PictureLayer).picture;
            expect(picture, isNotNull);
            await tester.scrollUntilVisible(
              find.text('Item 79'),
              400,
              scrollable: find.descendant(
                of: find.byType(AppSkinBottomSheetSurface),
                matching: find.byType(Scrollable),
              ),
              maxScrolls: 30,
            );
            // Reusing the display list proves that scrolling did not repaint
            // the static artwork; this is not a device frame-rate benchmark.
            expect((layer.firstChild! as PictureLayer).picture, same(picture));
            await tester.tap(find.text('Item 79'));
            await tester.pumpAndSettle();
            expect(result, 79);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
