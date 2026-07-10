import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app_message_service.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets('shows a top-centered error toast on compact layouts', (
    tester,
  ) async {
    await _pumpHost(tester, width: 400);

    AppMessageService.showError('网络错误');
    await _pumpToastEntrance(tester);

    expect(find.text('网络错误'), findsOneWidget);
    final toastCenter = tester.getCenter(find.text('网络错误'));
    expect(toastCenter.dx, closeTo(200, 80));
    expect(toastCenter.dy, lessThan(150));

    await _dismissToasts(tester);
  });

  testWidgets('shows a top-right error toast on wide layouts', (tester) async {
    await _pumpHost(tester, width: 1000);

    AppMessageService.showError('桌面端错误');
    await _pumpToastEntrance(tester);

    expect(find.text('桌面端错误'), findsOneWidget);
    final toastCenter = tester.getCenter(find.text('桌面端错误'));
    expect(toastCenter.dx, greaterThan(700));
    expect(toastCenter.dy, lessThan(150));

    await _dismissToasts(tester);
  });

  testWidgets('ignores empty error messages', (tester) async {
    await _pumpHost(tester, width: 400);

    AppMessageService.showError('   ');
    await tester.pump();

    expect(find.byType(ToastificationTheme), findsNothing);
  });

  testWidgets('suppresses duplicate errors within the cooldown', (
    tester,
  ) async {
    await _pumpHost(tester, width: 400);

    AppMessageService.showError('重复错误');
    AppMessageService.showError('重复错误');
    await _pumpToastEntrance(tester);

    expect(find.text('重复错误'), findsOneWidget);

    await _dismissToasts(tester);
  });

  testWidgets('automatically dismisses an error toast', (tester) async {
    await _pumpHost(tester, width: 400);

    AppMessageService.showError('短暂错误');
    await _pumpToastEntrance(tester);
    expect(find.text('短暂错误'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('短暂错误'), findsNothing);
  });

  testWidgets('shows success, info, and warning message variants', (
    tester,
  ) async {
    await _pumpHost(tester, width: 400);

    for (final entry in <(String, void Function(String))>[
      ('操作成功', AppMessageService.showSuccess),
      ('普通信息', AppMessageService.showInfo),
      ('注意事项', AppMessageService.showWarning),
    ]) {
      entry.$2(entry.$1);
      await _pumpToastEntrance(tester);
      expect(find.text(entry.$1), findsOneWidget);
    }

    await _dismissToasts(tester);
  });

  testWidgets('uses dark theme surface and foreground colors', (tester) async {
    final theme = ThemeData.dark(useMaterial3: true);
    await _pumpHost(tester, width: 400, theme: theme);

    AppMessageService.showError('暗色模式错误');
    await _pumpToastEntrance(tester);

    final containerColors = tester
        .widgetList<Container>(find.byType(Container))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color?.toARGB32());
    expect(
      containerColors,
      contains(theme.colorScheme.surfaceContainerHigh.toARGB32()),
    );
    final textStyles = tester
        .widgetList<DefaultTextStyle>(
          find.ancestor(
            of: find.text('暗色模式错误'),
            matching: find.byType(DefaultTextStyle),
          ),
        )
        .map((widget) => widget.style.color);
    expect(textStyles, contains(theme.colorScheme.onSurface));

    await _dismissToasts(tester);
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required double width,
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: rootNavigatorKey,
      theme: theme,
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
  await tester.pump();
}

Future<void> _dismissToasts(WidgetTester tester) async {
  toastification.dismissAll(delayForAnimation: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _pumpToastEntrance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}
