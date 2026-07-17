import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/app/config/app_player_background_style.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_feature_state.dart';
import 'package:he_music_flutter/features/online/presentation/controllers/online_controller.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:toastification/toastification.dart';

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
    expect(find.text('皮肤'), findsOneWidget);
    expect(find.text('皮肤动画'), findsOneWidget);
    expect(find.text('黑白模式'), findsOneWidget);
    expect(find.text('播放器背景样式'), findsOneWidget);
  });

  testWidgets('immersive skin disables manual accent and shows skin state', (
    tester,
  ) async {
    final container = _createContainer(
      authToken: null,
      skinId: AppSkinRegistry.citySoundCreatorId,
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();
    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();

    expect(find.text('跟随皮肤'), findsWidgets);
    expect(find.text('城市声场创作者'), findsOneWidget);
    final accentTile = tester.widget<ListTile>(
      find.ancestor(of: find.text('主题色'), matching: find.byType(ListTile)),
    );
    expect(accentTile.onTap, isNull);
    expect(accentTile.enabled, isFalse);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('settings-item-theme-accent')),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsNothing,
    );
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

  testWidgets('signed out account section only shows sign in entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();

    await tester.tap(find.text('帐号'));
    await tester.pumpAndSettle();

    expect(find.text('登录帐号'), findsOneWidget);
    expect(find.text('个人资料'), findsNothing);
    expect(find.text('修改密码'), findsNothing);
    expect(find.text('设备管理'), findsNothing);
    expect(find.text('退出帐号'), findsNothing);
  });

  testWidgets('signed in account section shows all management entries', (
    tester,
  ) async {
    final container = _createContainer(authToken: 'token');
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();
    await tester.tap(find.text('帐号'));
    await tester.pumpAndSettle();

    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('修改密码'), findsOneWidget);
    expect(find.text('设备管理'), findsOneWidget);
    expect(find.text('退出帐号'), findsOneWidget);
    expect(find.text('登录帐号'), findsNothing);

    final logoutText = tester.widget<Text>(find.text('退出帐号'));
    expect(
      logoutText.style?.color,
      Theme.of(tester.element(find.text('退出帐号'))).colorScheme.error,
    );
  });

  testWidgets('signed out search does not expose protected account entries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('settings-search-field')),
      '个人资料',
    );
    await tester.pump();

    expect(find.text('帐号 / 登录帐号'), findsOneWidget);
    expect(find.text('帐号 / 个人资料'), findsNothing);
  });

  testWidgets('logout requires confirmation and cancel keeps session', (
    tester,
  ) async {
    final container = _createContainer(authToken: 'token');
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();
    await tester.tap(find.text('帐号'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出帐号'));
    await tester.pumpAndSettle();

    expect(find.text('退出帐号？'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    final controller =
        container.read(onlineControllerProvider.notifier)
            as _TestOnlineController;
    expect(controller.logoutCalls, 0);
    expect(container.read(appConfigProvider).authToken, 'token');
  });

  testWidgets('confirmed logout clears session and returns home', (
    tester,
  ) async {
    final container = _createContainer(authToken: 'token');
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: AppRoutes.settings,
      routes: <GoRoute>[
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Scaffold(body: Text('home-page')),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('帐号'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出帐号'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '退出帐号'));
    await tester.pumpAndSettle();

    final controller =
        container.read(onlineControllerProvider.notifier)
            as _TestOnlineController;
    expect(controller.logoutCalls, 1);
    expect(container.read(appConfigProvider).authToken, isNull);
    expect(find.text('home-page'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
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

ProviderContainer _createContainer({
  required String? authToken,
  String skinId = AppSkinRegistry.classicId,
}) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(authToken: authToken, skinId: skinId),
      ),
      onlineControllerProvider.overrideWith(_TestOnlineController.new),
    ],
  );
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({required this.authToken, required this.skinId});

  final String? authToken;
  final String skinId;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      authToken: authToken,
      skinId: skinId,
      clearToken: authToken == null,
    );
  }
}

class _TestOnlineController extends OnlineController {
  int logoutCalls = 0;

  @override
  OnlineFeatureState build() => OnlineFeatureState.initial;

  @override
  Future<void> logout() async {
    logoutCalls++;
    ref.read(appConfigProvider.notifier).clearAuthToken();
    state = OnlineFeatureState.initial;
  }
}
