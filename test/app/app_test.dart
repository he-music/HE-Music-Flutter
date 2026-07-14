import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/app.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_environment.dart';
import 'package:he_music_flutter/app/config/app_theme_mode.dart';
import 'package:he_music_flutter/app/router/app_router.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/startup/app_startup_provider.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';

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

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({required this.themeMode, required this.localeCode});

  final AppThemeMode themeMode;
  final String localeCode;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: localeCode,
      themeMode: themeMode,
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
