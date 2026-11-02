import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_alert_dialog.dart';

void main() {
  for (final style in AppUiStyle.values) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$style alert keeps results and readable actions at $brightness ${scale}x',
          (tester) async {
            tester.view.physicalSize = const Size(320, 700);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            bool? result;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  brightness: brightness,
                  extensions: [AppUiTheme(style: style)],
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async {
                        result = await showDialog<bool>(
                          context: context,
                          builder: (context) => AppAlertDialog(
                            title: const Text('Delete selected lyrics?'),
                            content: const Text(
                              'The songs will use their default lyrics.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Keep'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete selected lyrics'),
                              ),
                            ],
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
            if (style == AppUiStyle.cupertino) {
              expect(find.byType(CupertinoAlertDialog), findsOneWidget);
              expect(
                tester
                    .widgetList<CupertinoDialogAction>(
                      find.byType(CupertinoDialogAction),
                    )
                    .last
                    .isDestructiveAction,
                isTrue,
              );
            } else {
              expect(find.byType(AlertDialog), findsOneWidget);
            }
            await tester.tap(find.text('Keep'));
            await tester.pumpAndSettle();
            expect(result, isFalse);
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Delete selected lyrics'));
            await tester.pumpAndSettle();
            expect(result, isTrue);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('Cupertino alert preserves disabled and rich actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [AppUiTheme(style: AppUiStyle.cupertino)],
        ),
        home: const Scaffold(
          body: AppAlertDialog(
            title: Text('Save'),
            content: TextField(),
            actions: [TextButton(onPressed: null, child: Text('Waiting'))],
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
          .onPressed,
      isNull,
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
