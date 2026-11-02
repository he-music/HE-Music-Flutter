import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_search_field.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets(
      '$style search shows keyboard focus feedback without resetting input',
      (tester) async {
        final controller = TextEditingController();
        final focus = FocusNode();
        final previous = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        addTearDown(previous.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [AppUiTheme(style: style)]),
            home: Scaffold(
              body: Column(
                children: [
                  TextButton(
                    focusNode: previous,
                    onPressed: () {},
                    child: const Text('Before'),
                  ),
                  AppSearchField(
                    controller: controller,
                    focusNode: focus,
                    placeholderPrimary: 'Search',
                  ),
                ],
              ),
            ),
          ),
        );
        final input = find.byType(
          style == AppUiStyle.cupertino ? CupertinoTextField : TextField,
        );
        await tester.tap(input);
        await tester.pump();
        final editable = tester.state(find.byType(EditableText));
        await tester.enterText(input, 'keep input');
        await tester.pump();
        previous.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        if (style == AppUiStyle.cupertino) {
          expect(
            tester.widget<CupertinoTextField>(input).decoration!.border,
            isNotNull,
          );
        } else {
          final border =
              tester.widget<TextField>(input).decoration!.focusedBorder!
                  as OutlineInputBorder;
          expect(border.borderSide.width, 1.2);
        }
        expect(tester.state(find.byType(EditableText)), same(editable));
        expect(controller.text, 'keep input');
        await tester.tap(input);
        await tester.pump();
        expect(controller.text, 'keep input');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
