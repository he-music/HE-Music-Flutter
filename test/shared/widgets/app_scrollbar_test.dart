import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_scrollbar.dart';

void main() {
  testWidgets('scrollbar style changes preserve scrollable and input state', (
    tester,
  ) async {
    final style = ValueNotifier(AppUiStyle.material);
    final scroll = ScrollController();
    addTearDown(style.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<AppUiStyle>(
        valueListenable: style,
        builder: (context, current, child) => AppUiStyleScope(
          style: current,
          child: MaterialApp(
            home: Scaffold(
              body: AppScrollbar(
                controller: scroll,
                child: _Probe(scroll: scroll),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Preserve this edit');
    final state = tester.state<_ProbeState>(find.byType(_Probe));
    final focus = FocusManager.instance.primaryFocus;
    for (final next in [AppUiStyle.cupertino, AppUiStyle.material]) {
      style.value = next;
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(focus));
      expect(state.text.text, 'Preserve this edit');
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    scroll.jumpTo(300);
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(300, .1));
    final scrollable = tester.state(find.byType(Scrollable));
    for (final next in [AppUiStyle.cupertino, AppUiStyle.material]) {
      style.value = next;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(_Probe)), same(state));
      expect(tester.state(find.byType(Scrollable)), same(scrollable));
      expect(scroll.offset, closeTo(300, .1));
      expect(state.text.text, 'Preserve this edit');
      expect(
        find.byType(
          next == AppUiStyle.cupertino ? CupertinoScrollbar : Scrollbar,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}

class _Probe extends StatefulWidget {
  const _Probe({required this.scroll});
  final ScrollController scroll;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    controller: widget.scroll,
    children: [
      TextField(controller: text),
      for (var index = 0; index < 40; index++)
        SizedBox(height: 56, child: Text('Row $index')),
    ],
  );
}
