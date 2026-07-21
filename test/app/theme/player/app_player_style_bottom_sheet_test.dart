import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_bottom_sheet.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_boundary.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_models.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';

void main() {
  testWidgets(
    'player sheet preserves result and uses shared light dark colors',
    (tester) async {
      final cases =
          <({ThemeMode mode, String playerStyleId, AppPlayerSheetStyle sheet})>[
            (
              mode: ThemeMode.light,
              playerStyleId: AppPlayerStyleRegistry.vinylId,
              sheet: AppPlayerSheetStyle.light,
            ),
            (
              mode: ThemeMode.light,
              playerStyleId: AppPlayerStyleRegistry.artistPhotoId,
              sheet: AppPlayerSheetStyle.light,
            ),
            (
              mode: ThemeMode.dark,
              playerStyleId: AppPlayerStyleRegistry.classicId,
              sheet: AppPlayerSheetStyle.dark,
            ),
            (
              mode: ThemeMode.dark,
              playerStyleId: AppPlayerStyleRegistry.cassetteId,
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
                () => _PlayerConfigController(testCase.playerStyleId),
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
        expect(bottomSheet.backgroundColor, testCase.sheet.backgroundColor);
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

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(result, 7);
      }
    },
  );
}

class _PlayerConfigController extends AppConfigController {
  _PlayerConfigController(this.playerStyleId);

  final String playerStyleId;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(playerStyleId: playerStyleId);
  }
}
