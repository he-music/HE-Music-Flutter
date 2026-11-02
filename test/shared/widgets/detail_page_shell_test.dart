import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/detail_page_shell.dart';

void main() {
  for (final style in AppUiStyle.values) {
    for (final resize in <bool>[false, true]) {
      testWidgets(
        'nested scaffold avoids keyboard once with style=$style resize=$resize',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(400, 800);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetViewInsets);
          const bodyKey = ValueKey('body');
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(extensions: [AppUiTheme(style: style)]),
              home: DetailPageShell(
                resizeToAvoidBottomInset: resize,
                child: const Scaffold(body: SizedBox.expand(key: bodyKey)),
              ),
            ),
          );
          expect(tester.getSize(find.byKey(bodyKey)).height, 800);

          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pump();
          expect(tester.getSize(find.byKey(bodyKey)).height, 500);
          expect(tester.takeException(), isNull);

          tester.view.viewInsets = const FakeViewPadding();
          await tester.pump();
          expect(tester.getSize(find.byKey(bodyKey)).height, 800);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
