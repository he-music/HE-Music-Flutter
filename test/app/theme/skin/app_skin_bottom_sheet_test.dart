import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_bottom_sheet.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';

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
      skin.light.colors.bottomSheetBackground,
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(result, 7);
  });
}
