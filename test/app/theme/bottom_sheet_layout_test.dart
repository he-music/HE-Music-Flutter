import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_bottom_sheet.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_bottom_sheet.dart';
import 'package:he_music_flutter/shared/widgets/app_sheet_header.dart';
import 'package:he_music_flutter/shared/widgets/app_sheet_close_button.dart';

void main() {
  for (final style in AppUiStyle.values) {
    for (final playerStyled in [false, true]) {
      testWidgets(
        '$style player=$playerStyled short sheet fits and avoids IME without losing edits',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetViewInsets);
          final controller = TextEditingController();
          final focus = FocusNode();
          addTearDown(controller.dispose);
          addTearDown(focus.dispose);
          int? result = 42;
          var completed = false;
          Widget body(BuildContext context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppSheetHeader(title: 'Draft'),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: TextField(controller: controller, focusNode: focus),
                ),
              ),
            ],
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(extensions: [AppUiTheme(style: style)]),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await (playerStyled
                          ? showPlayerStyledBottomSheet<int>(
                              context: context,
                              fitContent: true,
                              heightFactor: 0.8,
                              builder: body,
                            )
                          : showAppThemedBottomSheet<int>(
                              context: context,
                              fitContent: true,
                              heightFactor: 0.8,
                              builder: body,
                            ));
                      completed = true;
                    },
                    child: const Text('Open draft'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open draft'));
          await tester.pumpAndSettle();
          expect(
            tester.getSize(find.byType(BottomSheet)).height,
            lessThan(300),
          );
          final route = ModalRoute.of(tester.element(find.byType(TextField)));
          expect(route, isA<PopupRoute<int>>());
          await tester.enterText(find.byType(TextField), 'Unsaved text');
          focus.requestFocus();
          tester.view.viewInsets = const FakeViewPadding(bottom: 320);
          await tester.pumpAndSettle();
          expect(focus.hasFocus, isTrue);
          expect(controller.text, 'Unsaved text');
          expect(
            tester.getBottomLeft(find.byType(TextField)).dy,
            lessThanOrEqualTo(524),
          );
          expect(
            ModalRoute.of(tester.element(find.byType(TextField))),
            same(route),
          );
          await tester.tap(find.byType(AppSheetCloseButton));
          await tester.pumpAndSettle();
          expect(completed, isTrue);
          expect(result, isNull);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
