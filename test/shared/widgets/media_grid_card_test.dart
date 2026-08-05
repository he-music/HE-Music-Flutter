import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/media_grid_card.dart';

void main() {
  group('MediaGridCard', () {
    testWidgets('应显示标题和副标题', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MediaGridCard(
            kind: MediaGridCardKind.album,
            title: '专辑名',
            subtitle: '歌手名',
            coverUrl: '',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('专辑名'), findsOneWidget);
      expect(find.text('歌手名'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('专辑名'), matching: find.byType(Stack)),
        findsNothing,
        reason: '默认媒体卡片仍在封面外显示文字',
      );
    });

    testWidgets('subtitle 为空时不渲染副标题', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MediaGridCard(
            kind: MediaGridCardKind.album,
            title: 'Title',
            subtitle: '  ',
            coverUrl: '',
            onTap: () {},
          ),
        ),
      );

      // 只有标题，没有副标题
      expect(find.text('Title'), findsOneWidget);
      final texts = tester.widgetList(find.byType(Text)).toList();
      expect(texts.length, 1);
    });

    testWidgets('overlayText 将标题和可选副标题放入封面', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MediaGridCard(
            kind: MediaGridCardKind.playlist,
            title: '快捷入口',
            subtitle: '每日更新',
            coverUrl: '',
            overlayText: true,
            onTap: () {},
          ),
        ),
      );

      final coverStack = find.ancestor(
        of: find.text('快捷入口'),
        matching: find.byType(Stack),
      );
      expect(coverStack, findsOneWidget);
      expect(
        find.descendant(of: coverStack, matching: find.text('每日更新')),
        findsOneWidget,
      );
    });

    testWidgets('caption 存在时应显示', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MediaGridCard(
            kind: MediaGridCardKind.album,
            title: 'T',
            subtitle: '',
            caption: '2024',
            coverUrl: '',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('2024'), findsOneWidget);
    });

    testWidgets('点击应触发 onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          MediaGridCard(
            kind: MediaGridCardKind.album,
            title: 'T',
            subtitle: '',
            coverUrl: '',
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('T'));
      expect(tapped, isTrue);
    });

    testWidgets('selected 为 true 时应显示选中样式', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MediaGridCard(
            kind: MediaGridCardKind.album,
            title: 'T',
            subtitle: '',
            coverUrl: '',
            selected: true,
            onTap: () {},
          ),
        ),
      );

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNot(Border.all(color: Colors.transparent)));
    });

    testWidgets('showCenterPlayIcon 为 true 时应显示图标', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MediaGridCard(
            kind: MediaGridCardKind.album,
            title: 'T',
            subtitle: '',
            coverUrl: '',
            showCenterPlayIcon: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    });

    testWidgets('playCount 非空时应显示播放次数', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MediaGridCard(
            kind: MediaGridCardKind.album,
            title: 'T',
            subtitle: '',
            coverUrl: '',
            playCount: '12345',
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('kind 为 playlist 时无封面 URL 应显示列表图标', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MediaGridCard(
            kind: MediaGridCardKind.playlist,
            title: 'T',
            subtitle: '',
            coverUrl: '',
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
    });

    testWidgets('kind 为 album 时无封面 URL 应显示专辑图标', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MediaGridCard(
            kind: MediaGridCardKind.album,
            title: 'T',
            subtitle: '',
            coverUrl: '',
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.album_rounded), findsOneWidget);
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 200, height: 300, child: child)),
  );
}
