import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_bottom_sheet.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_boundary.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_models.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';

void main() {
  testWidgets(
    'player sheet preserves result, colors, and system overlay style',
    (tester) async {
      final cases =
          <({
            ThemeMode mode,
            String playerStageId,
            String playerBackdropId,
            String playerLyricsId,
            AppPlayerSheetStyle sheet,
          })>[
            (
              mode: ThemeMode.light,
              playerStageId: AppPlayerStageRegistry.vinylId,
              playerBackdropId: AppPlayerBackdropRegistry.coverGradientId,
              playerLyricsId: AppPlayerLyricsRegistry.legacyId,
              sheet: AppPlayerSheetStyle.light,
            ),
            (
              mode: ThemeMode.light,
              playerStageId: AppPlayerStageRegistry.classicId,
              playerBackdropId: AppPlayerBackdropRegistry.artistPhotoId,
              playerLyricsId: AppPlayerLyricsRegistry.legacyId,
              sheet: AppPlayerSheetStyle.light,
            ),
            (
              mode: ThemeMode.dark,
              playerStageId: AppPlayerStageRegistry.classicId,
              playerBackdropId: AppPlayerBackdropRegistry.coverGradientId,
              playerLyricsId: AppPlayerLyricsRegistry.legacyId,
              sheet: AppPlayerSheetStyle.dark,
            ),
            (
              mode: ThemeMode.dark,
              playerStageId: AppPlayerStageRegistry.cassetteId,
              playerBackdropId: AppPlayerBackdropRegistry.coverGradientId,
              playerLyricsId: AppPlayerLyricsRegistry.legacyId,
              sheet: AppPlayerSheetStyle.dark,
            ),
          ];

      for (final testCase in cases) {
        int? result;
        ColorScheme? sheetColorScheme;
        SliderThemeData? sheetSliderTheme;
        BottomSheetThemeData? sheetBottomSheetTheme;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWith(
                () => _PlayerConfigController(
                  playerStageId: testCase.playerStageId,
                  playerBackdropId: testCase.playerBackdropId,
                  playerLyricsId: testCase.playerLyricsId,
                ),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: testCase.mode,
              home: AppPlayerStyleBoundary(
                child: Builder(
                  builder: (context) => FilledButton(
                    onPressed: () async {
                      result = await showPlayerStyledBottomSheet<int>(
                        context: context,
                        builder: (sheetContext) {
                          final theme = Theme.of(sheetContext);
                          sheetColorScheme = theme.colorScheme;
                          sheetSliderTheme = theme.sliderTheme;
                          sheetBottomSheetTheme = theme.bottomSheetTheme;
                          return TextButton(
                            onPressed: () => Navigator.of(sheetContext).pop(7),
                            child: const Text('Close'),
                          );
                        },
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final bottomSheet = tester.widget<BottomSheet>(
          find.byType(BottomSheet),
        );
        expect(bottomSheet.backgroundColor, Colors.transparent);
        expect(_playerSheetStyle(tester), testCase.sheet);
        expect(sheetColorScheme?.surface, testCase.sheet.backgroundColor);
        expect(
          sheetColorScheme?.surfaceContainerHighest,
          testCase.sheet.backgroundColor,
        );
        expect(sheetColorScheme?.onSurface, testCase.sheet.foregroundColor);
        expect(
          sheetColorScheme?.onSurfaceVariant,
          testCase.sheet.secondaryForegroundColor,
        );
        expect(
          sheetBottomSheetTheme?.dragHandleColor,
          testCase.sheet.handleColor,
        );
        expect(
          sheetSliderTheme?.activeTrackColor,
          testCase.sheet.foregroundColor,
        );
        expect(
          find.byKey(const ValueKey<String>('player-sheet-surface')),
          findsOne,
        );
        final overlayStyleGuard = tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byKey(
                const ValueKey<String>('player-system-ui-overlay-style-guard'),
              ),
            );
        expect(
          overlayStyleGuard.value,
          appPlayerSystemOverlayStyle,
        );

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(result, 7);
        expect(
          find.byKey(
            const ValueKey<String>('player-system-ui-overlay-style-guard'),
          ),
          findsNothing,
        );
      }
    },
  );

  testWidgets('open player sheet follows app brightness changes', (
    tester,
  ) async {
    final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
    var sheetBuildCount = 0;
    addTearDown(themeMode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(
            () => _PlayerConfigController(
              playerStageId: AppPlayerStageRegistry.classicId,
            ),
          ),
        ],
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: themeMode,
          builder: (context, mode, child) => MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: mode,
            home: AppPlayerStyleBoundary(
              child: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showPlayerStyledBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) {
                      sheetBuildCount += 1;
                      return TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Close'),
                      );
                    },
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(_playerSheetStyle(tester), AppPlayerSheetStyle.light);
    expect(_renderedTextColor(tester, 'Close'), const Color(0xFF151515));
    expect(
      _playerSheetHandleColor(tester),
      AppPlayerSheetStyle.light.handleColor,
    );
    final initialSheetBuildCount = sheetBuildCount;

    themeMode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    expect(_playerSheetStyle(tester), AppPlayerSheetStyle.dark);
    expect(_renderedTextColor(tester, 'Close'), const Color(0xFFF5F5F5));
    expect(
      _playerSheetHandleColor(tester),
      AppPlayerSheetStyle.dark.handleColor,
    );
    expect(sheetBuildCount, initialSheetBuildCount);
    expect(
      find.byKey(
        const ValueKey<String>('player-system-ui-overlay-style-guard'),
      ),
      findsOne,
    );

    themeMode.value = ThemeMode.light;
    await tester.pumpAndSettle();
    expect(_playerSheetStyle(tester), AppPlayerSheetStyle.light);
    expect(_renderedTextColor(tester, 'Close'), const Color(0xFF151515));
    expect(sheetBuildCount, initialSheetBuildCount);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });
}

AppPlayerSheetStyle _playerSheetStyle(WidgetTester tester) {
  return tester
      .widget<PlayerSheetSurface>(find.byType(PlayerSheetSurface))
      .style;
}

Color? _renderedTextColor(WidgetTester tester, String text) {
  final richText = tester.widget<RichText>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)),
  );
  return richText.text.style?.color;
}

Color? _playerSheetHandleColor(WidgetTester tester) {
  final handle = tester.widget<DecoratedBox>(
    find.byKey(const ValueKey<String>('player-sheet-drag-handle')),
  );
  return (handle.decoration as BoxDecoration).color;
}

class _PlayerConfigController extends AppConfigController {
  _PlayerConfigController({
    this.playerStageId = AppPlayerStageRegistry.classicId,
    this.playerBackdropId = AppPlayerBackdropRegistry.coverGradientId,
    this.playerLyricsId = AppPlayerLyricsRegistry.legacyId,
  });

  final String playerStageId;
  final String playerBackdropId;
  final String playerLyricsId;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      playerStageId: playerStageId,
      playerBackdropId: playerBackdropId,
      playerLyricsId: playerLyricsId,
    );
  }
}
