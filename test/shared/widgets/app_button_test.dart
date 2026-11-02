import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_button.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets('$style icon actions retain callbacks and disabled state', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppUiTheme(style: style)]),
          home: Scaffold(
            body: Column(
              children: [
                AppButton.filledIcon(
                  onPressed: () => calls++,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const AppButton.outlinedIcon(
                  onPressed: null,
                  icon: Icon(Icons.cloud_off),
                  label: Text('Unavailable'),
                ),
                AppButton.textIcon(
                  onPressed: () => calls++,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.edit),
                  iconAlignment: IconAlignment.end,
                  label: const Text('Edit'),
                ),
              ],
            ),
          ),
        ),
      );
      if (style == AppUiStyle.cupertino) {
        expect(find.byType(CupertinoButton), findsNWidgets(3));
        final edit = tester.widget<CupertinoButton>(
          find.ancestor(
            of: find.text('Edit'),
            matching: find.byType(CupertinoButton),
          ),
        );
        expect(edit.foregroundColor, Colors.red);
        expect(find.byType(FilledButton), findsNothing);
      } else {
        expect(find.byType(FilledButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(find.byType(TextButton), findsOneWidget);
      }
      expect(
        tester.getCenter(find.byIcon(Icons.edit)).dx,
        greaterThan(tester.getCenter(find.text('Edit')).dx),
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.tap(find.text('Unavailable'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
