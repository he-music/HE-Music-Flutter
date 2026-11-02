import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_refreshable_scroll_view.dart';

void main() {
  for (final style in AppUiStyle.values) {
    for (final empty in [false, true]) {
      testWidgets(
        '$style pull refreshes ${empty ? "empty" : "populated"} content once',
        (tester) async {
          var calls = 0;
          final pending = Completer<void>();
          await tester.pumpWidget(
            MaterialApp(
              home: AppUiStyleScope(
                style: style,
                child: Scaffold(
                  body: AppRefreshableScrollView(
                    onRefresh: () {
                      calls++;
                      return pending.future;
                    },
                    slivers: [
                      if (!empty)
                        const SliverToBoxAdapter(child: SizedBox(height: 1600)),
                    ],
                  ),
                ),
              ),
            ),
          );
          // The resting refresh sliver has zero paint extent.
          expect(
            find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
            style == AppUiStyle.cupertino ? findsOneWidget : findsNothing,
          );
          await tester.timedDrag(
            find.byType(CustomScrollView),
            const Offset(0, 500),
            const Duration(seconds: 1),
          );
          await tester.pump(const Duration(seconds: 1));
          expect(calls, 1);
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, 500),
          );
          await tester.pump(const Duration(seconds: 1));
          expect(calls, 1);
          pending.complete();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('style changes retain scroll position and local input state', (
    tester,
  ) async {
    final style = ValueNotifier(AppUiStyle.material);
    final controller = ScrollController();
    addTearDown(style.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: style,
          builder: (context, value, _) => AppUiStyleScope(
            style: value,
            child: Scaffold(
              body: AppRefreshableScrollView(
                controller: controller,
                onRefresh: () async {},
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: const [
                  SliverToBoxAdapter(child: TextField()),
                  SliverToBoxAdapter(child: SizedBox(height: 2000)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'keep input');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final input = find.byType(EditableText, skipOffstage: false);
    final inputState = tester.state(input);
    controller.jumpTo(360);
    await tester.pumpAndSettle();
    final scrollState = tester.state(find.byType(Scrollable));
    for (final value in [AppUiStyle.cupertino, AppUiStyle.material]) {
      style.value = value;
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(360, 0.1));
      expect(tester.state(find.byType(Scrollable)), same(scrollState));
      expect(tester.state(input), same(inputState));
      expect(tester.widget<EditableText>(input).controller.text, 'keep input');
    }
  });
}
