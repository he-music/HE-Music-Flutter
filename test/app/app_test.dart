import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/app.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_environment.dart';
import 'package:he_music_flutter/app/config/app_theme_mode.dart';
import 'package:he_music_flutter/app/i18n/app_i18n.dart';
import 'package:he_music_flutter/app/router/app_router.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/startup/app_startup_provider.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_background.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_state.dart';
import 'package:he_music_flutter/features/update/presentation/controllers/update_controller.dart';
import 'package:he_music_flutter/features/update/presentation/providers/update_providers.dart';

void main() {
  setUpAll(AppEnvironment.initialize);

  testWidgets('app uses dark status bar icons for light theme by default', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(themeMode: AppThemeMode.light));
    await tester.pump();

    final overlayStyle = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byWidgetPredicate(
            (widget) => widget is AnnotatedRegion<SystemUiOverlayStyle>,
          ),
        )
        .first
        .value;

    expect(overlayStyle.statusBarIconBrightness, Brightness.dark);
    expect(overlayStyle.statusBarBrightness, Brightness.light);
    expect(overlayStyle.statusBarColor, Colors.transparent);
  });

  testWidgets('app uses light status bar icons for dark theme by default', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(themeMode: AppThemeMode.dark));
    await tester.pump();

    final overlayStyle = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byWidgetPredicate(
            (widget) => widget is AnnotatedRegion<SystemUiOverlayStyle>,
          ),
        )
        .first
        .value;

    expect(overlayStyle.statusBarIconBrightness, Brightness.light);
    expect(overlayStyle.statusBarBrightness, Brightness.dark);
    expect(overlayStyle.statusBarColor, Colors.transparent);
  });

  testWidgets('app follows system locale when locale code is system', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(themeMode: AppThemeMode.light, localeCode: 'system'),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.locale, isNull);
  });

  testWidgets('locale-code translations follow the system locale', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    expect(AppI18n.tByLocaleCode('system', 'startup.loading'), 'Starting');
  });

  testWidgets('app ignores unrelated config but still updates locale', (
    tester,
  ) async {
    late _MutableAppConfigController controller;
    final router = GoRouter(
      routes: <GoRoute>[
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(() {
            controller = _MutableAppConfigController();
            return controller;
          }),
          appRouterProvider.overrideWithValue(router),
        ],
        child: const HeMusicApp(),
      ),
    );
    await tester.pump();

    final initialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    controller.updateAuthToken('updated-token');
    await tester.pump();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)),
      same(initialApp),
    );

    controller.updateLocale('en');
    await tester.pump();

    final localizedApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(localizedApp, isNot(same(initialApp)));
    expect(localizedApp.locale, const Locale('en'));
  });

  testWidgets('app installs one fixed skin background below route content', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(themeMode: AppThemeMode.light));
    await tester.pump();

    expect(find.byType(AppSkinBackgroundLayer), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(AppSkinBackgroundLayer),
        matching: find.byType(Stack),
      ),
      findsWidgets,
    );
  });

  testWidgets('startup loading omits legacy gradient for immersive skin', (
    tester,
  ) async {
    final startup = Completer<void>();
    final router = _createStartupTestRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _buildStartupLoadingApp(
        router: router,
        startup: startup,
        skinId: 'city_sound_creator',
      ),
    );
    await tester.pump();

    expect(find.text('HE-Music'), findsOneWidget);
    expect(_legacyGradientFinder, findsNothing);
  });

  testWidgets('startup loading keeps legacy gradient for classic skin', (
    tester,
  ) async {
    final startup = Completer<void>();
    final router = _createStartupTestRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _buildStartupLoadingApp(
        router: router,
        startup: startup,
        skinId: 'classic',
      ),
    );
    await tester.pump();

    expect(_legacyGradientFinder, findsOneWidget);
  });

  testWidgets('startup 401 pushes login and system back returns home', (
    tester,
  ) async {
    final router = _createStartupTestRouter();
    addTearDown(router.dispose);
    final unauthorized = DioException(
      requestOptions: RequestOptions(path: '/v1/platforms'),
      response: Response<void>(
        requestOptions: RequestOptions(path: '/v1/platforms'),
        statusCode: 401,
      ),
      type: DioExceptionType.badResponse,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(
            () => _TestAppConfigController(
              themeMode: AppThemeMode.light,
              localeCode: 'zh',
            ),
          ),
          appRouterProvider.overrideWithValue(router),
          appStartupProvider.overrideWith(
            (ref) => Future<void>.error(unauthorized),
          ),
          appConfigDataSourceProvider.overrideWithValue(
            const _TestAppConfigDataSource(autoCheckUpdates: false),
          ),
        ],
        child: const HeMusicApp(enableStartupGateInTests: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('登录页'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.login);
    expect(router.state.uri.queryParameters['redirect'], AppRoutes.home);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.home);
  });

  testWidgets('startup network error retries platforms once then shows home', (
    tester,
  ) async {
    final router = _createStartupTestRouter();
    final apiClient = _RetryOnlineApiClient();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_HydratedTestAppConfigController.new),
          appRouterProvider.overrideWithValue(router),
          onlineApiClientProvider.overrideWithValue(apiClient),
          appConfigDataSourceProvider.overrideWithValue(
            const _TestAppConfigDataSource(autoCheckUpdates: false),
          ),
        ],
        child: const HeMusicApp(enableStartupGateInTests: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('启动失败'), findsOneWidget);
    expect(apiClient.fetchPlatformsCallCount, 1);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(apiClient.fetchPlatformsCallCount, 2);
  });

  testWidgets('startup transform timeout shows timeout guidance', (
    tester,
  ) async {
    final router = _createStartupTestRouter();
    addTearDown(router.dispose);
    final timeout = DioException.transformTimeout(
      timeout: const Duration(seconds: 1),
      requestOptions: RequestOptions(path: '/v1/platforms'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(
            () => _TestAppConfigController(
              themeMode: AppThemeMode.light,
              localeCode: 'zh',
            ),
          ),
          appRouterProvider.overrideWithValue(router),
          appStartupProvider.overrideWith((ref) => Future<void>.error(timeout)),
          appConfigDataSourceProvider.overrideWithValue(
            const _TestAppConfigDataSource(autoCheckUpdates: false),
          ),
        ],
        child: const HeMusicApp(enableStartupGateInTests: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('网络连接超时，请检查网络后重试。'), findsOneWidget);
  });

  testWidgets('startup checks updates only after initialization completes', (
    tester,
  ) async {
    final startup = Completer<void>();
    final router = _createStartupTestRouter();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(
          () => _TestAppConfigController(
            themeMode: AppThemeMode.light,
            localeCode: 'zh',
          ),
        ),
        appConfigDataSourceProvider.overrideWithValue(
          const _TestAppConfigDataSource(autoCheckUpdates: true),
        ),
        appRouterProvider.overrideWithValue(router),
        appStartupProvider.overrideWith((ref) => startup.future),
        updateControllerProvider.overrideWith(_CountingUpdateController.new),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HeMusicApp(enableStartupGateInTests: true),
      ),
    );
    await tester.pump();

    final controller =
        container.read(updateControllerProvider.notifier)
            as _CountingUpdateController;
    expect(controller.checkCount, 0);

    startup.complete();
    await tester.pump();
    await tester.pump();

    expect(controller.checkCount, 1);
  });
}

GoRouter _createStartupTestRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    routes: <GoRoute>[
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const Scaffold(body: Text('首页')),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const Scaffold(body: Text('登录页')),
      ),
    ],
  );
}

Widget _buildApp({required AppThemeMode themeMode, String localeCode = 'zh'}) {
  final router = GoRouter(
    routes: <GoRoute>[
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(
          themeMode: themeMode,
          localeCode: localeCode,
        ),
      ),
      appRouterProvider.overrideWithValue(router),
    ],
    child: const HeMusicApp(),
  );
}

Widget _buildStartupLoadingApp({
  required GoRouter router,
  required Completer<void> startup,
  required String skinId,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(
          themeMode: AppThemeMode.light,
          localeCode: 'zh',
          skinId: skinId,
        ),
      ),
      appRouterProvider.overrideWithValue(router),
      appStartupProvider.overrideWith((ref) => startup.future),
      appConfigDataSourceProvider.overrideWithValue(
        const _TestAppConfigDataSource(autoCheckUpdates: false),
      ),
    ],
    child: const HeMusicApp(enableStartupGateInTests: true),
  );
}

final Finder _legacyGradientFinder = find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      widget.decoration is BoxDecoration &&
      (widget.decoration as BoxDecoration).gradient is LinearGradient,
);

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({
    required this.themeMode,
    required this.localeCode,
    this.skinId = 'classic',
  });

  final AppThemeMode themeMode;
  final String localeCode;
  final String skinId;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: localeCode,
      themeMode: themeMode,
      skinId: skinId,
    );
  }
}

class _HydratedTestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'zh');
  }

  @override
  Future<void> waitUntilHydrated() => Future<void>.value();
}

class _MutableAppConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'zh');

  void updateAuthToken(String value) {
    state = state.copyWith(authToken: value);
  }

  void updateLocale(String value) {
    state = state.copyWith(localeCode: value);
  }
}

class _TestAppConfigDataSource extends AppConfigDataSource {
  const _TestAppConfigDataSource({required this.autoCheckUpdates});

  final bool autoCheckUpdates;

  @override
  Future<AppConfigState> load() async {
    return AppConfigState.initial.copyWith(autoCheckUpdates: autoCheckUpdates);
  }
}

class _CountingUpdateController extends UpdateController {
  int checkCount = 0;

  @override
  UpdateState build() => UpdateState.initial;

  @override
  Future<void> checkForUpdates() async {
    checkCount += 1;
  }
}

class _RetryOnlineApiClient extends OnlineApiClient {
  _RetryOnlineApiClient() : super(Dio());

  int fetchPlatformsCallCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchPlatforms({
    bool silentErrorMessage = false,
  }) async {
    fetchPlatformsCallCount += 1;
    if (fetchPlatformsCallCount == 1) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v1/platforms'),
        type: DioExceptionType.connectionError,
      );
    }
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'qq',
        'name': 'QQ',
        'shortname': 'QQ',
        'status': 1,
        'feature_support_flag': 0,
      },
    ];
  }
}
