import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/shared/widgets/app_adaptive_controls.dart';
import 'package:he_music_flutter/shared/widgets/song_list_item.dart';

void main() {
  for (final initialStyle in AppUiStyle.values) {
    testWidgets(
      '$initialStyle song inline state and focus survive changing UI style',
      (tester) async {
        final style = ValueNotifier(initialStyle);
        addTearDown(style.dispose);
        var rowTaps = 0;
        var inlineTaps = 0;
        const inlineKey = ValueKey('inline-action');
        await tester.pumpWidget(
          ValueListenableBuilder<AppUiStyle>(
            valueListenable: style,
            child: Scaffold(
              body: SongListItem(
                data: const SongListItemData(
                  title: 'Track',
                  artistAlbumText: 'Artist',
                  subtitleText: '',
                ),
                onTap: () => rowTaps++,
                contentAfterSubtitle: _InlineAction(
                  key: inlineKey,
                  onTap: () => inlineTaps++,
                ),
              ),
            ),
            builder: (context, value, child) => MaterialApp(
              theme: ThemeData(extensions: [AppUiTheme(style: value)]),
              home: child,
            ),
          ),
        );
        await tester.tap(find.text('Inline 0'));
        await tester.pumpAndSettle();
        final originalState = tester.state(find.byKey(inlineKey));
        final inlineFocus = Focus.of(tester.element(find.text('Inline 1')));
        inlineFocus.requestFocus();
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, same(inlineFocus));
        expect((rowTaps, inlineTaps), (0, 1));

        style.value = initialStyle == AppUiStyle.material
            ? AppUiStyle.cupertino
            : AppUiStyle.material;
        await tester.pumpAndSettle();
        expect(tester.state(find.byKey(inlineKey)), same(originalState));
        expect(find.text('Inline 1'), findsOneWidget);
        expect(FocusManager.instance.primaryFocus, same(inlineFocus));
        expect(
          Focus.of(tester.element(find.text('Inline 1'))),
          same(inlineFocus),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Inline 2'), findsOneWidget);
        expect((rowTaps, inlineTaps), (0, 2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$initialStyle press feedback keeps the content target and fires once',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [AppUiTheme(style: initialStyle)]),
            home: Scaffold(
              body: AppPressable(
                onTap: () => taps++,
                child: const SizedBox(width: 120, height: 48),
              ),
            ),
          ),
        );
        final pressable = find.byType(AppPressable);
        final before = tester.getRect(pressable);
        final gesture = await tester.startGesture(before.center);
        await tester.pump(const Duration(milliseconds: 120));
        final opacity = find.descendant(
          of: pressable,
          matching: find.byType(Opacity),
        );
        expect(
          tester.widget<Opacity>(opacity).opacity,
          initialStyle == AppUiStyle.cupertino ? 0.6 : 1,
        );
        expect(tester.getRect(pressable), before);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.widget<Opacity>(opacity).opacity, 1);
      },
    );
  }
}

class _InlineAction extends StatefulWidget {
  const _InlineAction({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  State<_InlineAction> createState() => _InlineActionState();
}

class _InlineActionState extends State<_InlineAction> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: () {
      setState(() => _count++);
      widget.onTap();
    },
    child: Text('Inline $_count'),
  );
}
