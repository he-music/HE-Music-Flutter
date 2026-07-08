import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/app/config/app_player_background_style.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/settings_page.dart';

void main() {
  testWidgets('mobile settings home shows search and four sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('settings-search-field')),
      findsOne,
    );
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('歌词'), findsOneWidget);
    expect(find.text('通用'), findsOneWidget);
  });

  testWidgets('mobile settings opens lyric section with three items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();

    await tester.tap(find.text('歌词'));
    await tester.pumpAndSettle();

    expect(find.text('歌词颜色'), findsOneWidget);
    expect(find.text('歌词大小'), findsOneWidget);
    expect(find.text('逐字歌词'), findsOneWidget);
  });

  testWidgets('mobile appearance section shows grouped settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();

    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();

    expect(find.text('主题与配色'), findsOneWidget);
    expect(find.text('显示效果'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('主题色'), findsOneWidget);
    expect(find.text('黑白模式'), findsOneWidget);
    expect(find.text('播放器背景样式'), findsOneWidget);
  });

  testWidgets('wide settings keeps mobile section list', (tester) async {
    tester.view.physicalSize = const Size(2700, 2700);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('歌词'), findsOneWidget);
    expect(find.text('主题'), findsNothing);
  });

  testWidgets('desktop search jumps to lyric font preset item', (tester) async {
    tester.view.physicalSize = const Size(2700, 2700);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey<String>('settings-search-field')),
      '歌词大小',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('歌词 / 歌词大小'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('settings-item-lyric-font-preset')),
      findsOneWidget,
    );
    expect(find.text('逐字歌词'), findsOneWidget);
  });

  testWidgets('word by word lyric switch updates config state', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();

    await tester.tap(find.text('歌词'));
    await tester.pumpAndSettle();

    expect(container.read(appConfigProvider).enableWordByWordLyric, isTrue);

    await tester.tap(find.text('逐字歌词'));
    await tester.pump();

    expect(container.read(appConfigProvider).enableWordByWordLyric, isFalse);
  });

  testWidgets('settings page does not show logout action', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();

    expect(find.text('退出登录'), findsNothing);
  });

  testWidgets('lyric highlight color shows auto summary when mode is auto', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(appConfigProvider.notifier)
        .setLyricHighlightMode(AppLyricHighlightMode.auto);

    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();

    await tester.tap(find.text('歌词'));
    await tester.pumpAndSettle();

    expect(find.text('自动'), findsOneWidget);
  });

  testWidgets('player background style sheet updates config state', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();

    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();

    expect(
      container.read(appConfigProvider).playerBackgroundStyle,
      AppPlayerBackgroundStyle.albumCover,
    );

    await tester.tap(find.text('播放器背景样式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('流体'));
    await tester.pumpAndSettle();

    expect(
      container.read(appConfigProvider).playerBackgroundStyle,
      AppPlayerBackgroundStyle.fluid,
    );
    expect(find.text('歌手写真'), findsNothing);
  });

  testWidgets('language sheet can select system locale', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();

    await tester.tap(find.text('通用'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跟随系统'));
    await tester.pumpAndSettle();

    expect(container.read(appConfigProvider).localeCode, 'system');
  });
}

Widget _buildSettingsApp({ProviderContainer? container}) {
  final scopeChild = MaterialApp(
    theme: ThemeData(platform: TargetPlatform.android),
    home: const SettingsPage(),
  );
  if (container == null) {
    return ProviderScope(child: scopeChild);
  }
  return UncontrolledProviderScope(container: container, child: scopeChild);
}
