import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_bottom_sheet.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets(
      '$style tall sheet scrolls immediately and preserves popup route semantics',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        int? result;
        Route<dynamic>? route;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [AppUiTheme(style: style)]),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showAppThemedBottomSheet<int>(
                      context: context,
                      isScrollControlled: true,
                      fixedHeightFactor: .8,
                      builder: (context) {
                        route = ModalRoute.of(context);
                        return ListView(
                          children: [
                            for (var i = 0; i < 60; i++)
                              ListTile(
                                title: Text('Song $i'),
                                onTap: () => Navigator.pop(context, i),
                              ),
                          ],
                        );
                      },
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
        expect(route, isA<PopupRoute<dynamic>>());
        final top = tester.getTopLeft(find.byType(BottomSheet)).dy;
        await tester.scrollUntilVisible(
          find.text('Song 59'),
          300,
          scrollable: find.byType(Scrollable),
        );
        expect(tester.getTopLeft(find.byType(BottomSheet)).dy, closeTo(top, 1));
        await tester.tap(find.text('Song 59'));
        await tester.pumpAndSettle();
        expect(result, 59);
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
