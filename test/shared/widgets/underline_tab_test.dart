import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/underline_tab.dart';

void main() {
  group('UnderlineTab', () {
    testWidgets('应显示 label 文本', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UnderlineTab(
            label: '歌曲',
            selected: false,
            enabled: true,
            onTap: _noop,
          ),
        ),
      );

      expect(find.text('歌曲'), findsOneWidget);
    });

    testWidgets('选中时应显示下划线', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UnderlineTab(
            label: 'Tab',
            selected: true,
            enabled: true,
            onTap: _noop,
          ),
        ),
      );

      // AnimatedContainer 选中时 width=22
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, isNot(Colors.transparent));
    });

    testWidgets('未选中时下划线宽度为 0', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UnderlineTab(
            label: 'Tab',
            selected: false,
            enabled: true,
            onTap: _noop,
          ),
        ),
      );

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(container.constraints?.maxWidth, 0);
    });

    testWidgets('enabled 为 false 时点击不应触发 onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          UnderlineTab(
            label: 'Tab',
            selected: false,
            enabled: false,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Tab'));
      expect(tapped, isFalse);
    });

    testWidgets('enabled 为 true 时点击应触发 onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          UnderlineTab(
            label: 'Tab',
            selected: false,
            enabled: true,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Tab'));
      expect(tapped, isTrue);
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void _noop() {}
