import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_feedback.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets('$style search failure retains retry and edit actions', (
      tester,
    ) async {
      var retries = 0;
      var edits = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppUiTheme(style: style)]),
          home: Scaffold(
            body: SearchFeedback(
              localeCode: 'en',
              error: 'Network unavailable',
              onRetry: () => retries++,
              onEditQuery: () => edits++,
            ),
          ),
        ),
      );
      expect(find.text('Network unavailable'), findsOneWidget);
      if (style == AppUiStyle.cupertino) {
        expect(find.byType(CupertinoButton), findsNWidgets(2));
        expect(find.byType(FilledButton), findsNothing);
      } else {
        expect(find.byType(FilledButton), findsOneWidget);
        expect(find.byType(TextButton), findsOneWidget);
      }
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retries, 1);
      await tester.tap(find.text('Edit search'));
      await tester.pumpAndSettle();
      expect(edits, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
