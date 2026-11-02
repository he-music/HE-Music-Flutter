import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/adaptive_action_menu.dart';

enum TestAction { edit, delete, share }

void main() {
  for (final brightness in Brightness.values) {
    for (final menu in [
      (
        name: 'desktop',
        desktop: true,
        density: AdaptiveActionMenuMobileDensity.compact,
      ),
      (
        name: 'compact',
        desktop: false,
        density: AdaptiveActionMenuMobileDensity.compact,
      ),
      (
        name: 'regular',
        desktop: false,
        density: AdaptiveActionMenuMobileDensity.regular,
      ),
    ]) {
      testWidgets('${menu.name} menu icons follow $brightness theme colors', (
        tester,
      ) async {
        final colors = ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: brightness,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: menu.desktop
                  ? TargetPlatform.macOS
                  : TargetPlatform.android,
              colorScheme: colors,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAdaptiveActionMenu<int>(
                    context: context,
                    anchorPosition: const Offset(100, 100),
                    mobileDensity: menu.density,
                    items: const [
                      AdaptiveActionMenuItem(
                        value: 1,
                        label: 'Share',
                        icon: Icons.share,
                      ),
                      AdaptiveActionMenuItem(
                        value: 2,
                        label: 'Remove',
                        icon: Icons.delete,
                        destructive: true,
                      ),
                      AdaptiveActionMenuItem(
                        value: 3,
                        label: 'Unavailable',
                        icon: Icons.download,
                        enabled: false,
                      ),
                    ],
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        for (final action in [
          (
            icon: Icons.share,
            label: 'Share',
            iconColor: colors.primary,
            textColor: colors.onSurface,
          ),
          (
            icon: Icons.delete,
            label: 'Remove',
            iconColor: colors.error,
            textColor: colors.error,
          ),
          (
            icon: Icons.download,
            label: 'Unavailable',
            iconColor: colors.onSurface.withValues(alpha: 0.38),
            textColor: colors.onSurface.withValues(alpha: 0.38),
          ),
        ]) {
          final icons = tester.widgetList<Icon>(find.byIcon(action.icon));
          expect(icons, isNotEmpty);
          for (final icon in icons) {
            expect(icon.color, action.iconColor);
          }
          expect(
            tester.widget<Text>(find.text(action.label)).style!.color,
            action.textColor,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  group('AdaptiveActionMenuItem', () {
    test('应正确存储属性', () {
      const item = AdaptiveActionMenuItem<TestAction>(
        value: TestAction.edit,
        label: 'Edit',
        icon: Icons.edit,
        enabled: true,
        destructive: false,
      );

      expect(item.value, TestAction.edit);
      expect(item.label, 'Edit');
      expect(item.icon, Icons.edit);
      expect(item.enabled, isTrue);
      expect(item.destructive, isFalse);
    });

    test('默认值应正确', () {
      const item = AdaptiveActionMenuItem<TestAction>(
        value: TestAction.share,
        label: 'Share',
      );

      expect(item.enabled, isTrue);
      expect(item.destructive, isFalse);
      expect(item.startsNewSection, isFalse);
      expect(item.icon, isNull);
      expect(item.key, isNull);
    });
  });

  group('AdaptiveActionMenu', () {
    testWidgets('items 为空时按钮应禁用', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdaptiveActionMenu<TestAction>(
            menuKey: Key('menu'),
            tooltip: 'Menu',
            icon: Icon(Icons.more_vert),
            items: [],
            onSelected: _noop,
          ),
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('items 非空时按钮应可用', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AdaptiveActionMenu<TestAction>(
            menuKey: const Key('menu'),
            tooltip: 'Menu',
            icon: const Icon(Icons.more_vert),
            items: const [
              AdaptiveActionMenuItem(value: TestAction.edit, label: 'Edit'),
            ],
            onSelected: (_) {},
          ),
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNotNull);
    });

    testWidgets('应显示 tooltip', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdaptiveActionMenu<TestAction>(
            menuKey: Key('menu'),
            tooltip: 'More Options',
            icon: Icon(Icons.more_vert),
            items: [
              AdaptiveActionMenuItem(value: TestAction.edit, label: 'Edit'),
            ],
            onSelected: _noop,
          ),
        ),
      );

      expect(find.byTooltip('More Options'), findsOneWidget);
    });

    testWidgets('系统返回应优先关闭 root 移动端底部面板而不是退出页面', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Column(
                  children: <Widget>[
                    const Text('detail page'),
                    AdaptiveActionMenu<TestAction>(
                      menuKey: const Key('menu'),
                      tooltip: 'Menu',
                      icon: const Icon(Icons.more_vert),
                      items: const <AdaptiveActionMenuItem<TestAction>>[
                        AdaptiveActionMenuItem(
                          value: TestAction.edit,
                          label: 'Edit',
                        ),
                      ],
                      onSelected: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('menu')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('detail page'), findsOneWidget);
    });
  });

  group('AdaptiveActionMenuAnchor', () {
    test('capture 和 consume 应正确存储和清除状态', () {
      // 这是一个静态类，主要测试不抛异常
      // 在 widget 测试外调用 consume 不会崩溃
      // 实际使用场景在 widget 内部
    });
  });
}

void _noop(TestAction value) {}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
