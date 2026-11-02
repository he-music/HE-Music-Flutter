import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_bottom_sheet.dart';

void main() {
  testWidgets(
    'Cupertino player action sheet preserves result, cancel and disabled action',
    (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [AppUiTheme(style: AppUiStyle.cupertino)],
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showPlayerCupertinoActionSheet<int>(
                    context: context,
                    title: const Text('Player'),
                    message: const Text('1.25x · 80%'),
                    actions: const [
                      PlayerCupertinoAction(value: 1, label: 'Style'),
                      PlayerCupertinoAction(
                        value: 2,
                        label: 'Unavailable',
                        enabled: false,
                      ),
                    ],
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
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.text('1.25x · 80%'), findsOneWidget);
      await tester.tap(find.text('Unavailable'));
      await tester.pump();
      expect(result, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();
      expect(result, 1);
      expect(find.byType(CupertinoActionSheet), findsNothing);
    },
  );
}
