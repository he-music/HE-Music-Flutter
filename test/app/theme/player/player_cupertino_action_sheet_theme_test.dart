import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_bottom_sheet.dart';

void main() {
  testWidgets(
    'Cupertino popup uses app accent instead of dark player scene tint',
    (tester) async {
      const appAccent = Color(0xFF007AFF);
      await tester.pumpWidget(
        AppUiStyleScope(
          style: AppUiStyle.cupertino,
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: appAccent,
              ).copyWith(primary: appAccent),
            ),
            home: Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(primary: Color(0xFFA2E7CB)),
              ),
              child: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showPlayerCupertinoActionSheet<String>(
                      context: context,
                      actions: const [
                        PlayerCupertinoAction(value: 'close', label: 'Close'),
                      ],
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(CupertinoActionSheet));
      expect(Theme.of(context).brightness, Brightness.light);
      expect(Theme.of(context).colorScheme.primary, appAccent);
      expect(CupertinoTheme.of(context).primaryColor, appAccent);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Cupertino player sheet applies dark player theme and custom accent',
    (tester) async {
      var result = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.dark(primary: Colors.orange),
            extensions: const [AppUiTheme(style: AppUiStyle.cupertino)],
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await showPlayerCupertinoActionSheet<void>(
                    context: context,
                    sheetBuilder: (popupContext) => CupertinoActionSheet(
                      actions: [
                        CupertinoActionSheetAction(
                          onPressed: () {
                            result = true;
                            Navigator.of(popupContext).pop();
                          },
                          child: const Text('Dynamic'),
                        ),
                      ],
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.of(popupContext).pop(),
                        child: const Text('Cancel'),
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
      final theme = tester.widget<CupertinoTheme>(
        find
            .ancestor(
              of: find.byType(CupertinoActionSheet),
              matching: find.byType(CupertinoTheme),
            )
            .last,
      );
      expect(theme.data.brightness, Brightness.dark);
      expect(theme.data.primaryColor, Colors.orange);
      await tester.tap(find.text('Dynamic'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    },
  );
}
