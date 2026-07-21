import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_navigation_service.dart';
import '../../app/config/app_config_controller.dart';
import '../../app/router/app_router.dart';
import '../../app/router/app_routes.dart';
import '../captcha/captcha_coordinator.dart';
import '../device/device_info_provider.dart';
import 'auth_token_interceptor.dart';
import 'captcha_challenge_interceptor.dart';
import 'error_message_interceptor.dart';
import 'token_refresh_interceptor.dart';
import 'unauthorized_redirect_interceptor.dart';

final apiDioProvider = Provider<Dio>((ref) {
  // 只监听网络相关字段，避免主题色等无关配置水合触发 Dio 重建，从而中断启动阶段请求。
  final (apiBaseUrl, localeCode) = ref.watch(
    appConfigProvider.select(
      (config) => (config.apiBaseUrl, config.localeCode),
    ),
  );
  final router = ref.watch(appRouterProvider);
  final configController = ref.read(appConfigProvider.notifier);
  final captchaCoordinator = CaptchaCoordinator(router);
  final baseUrl = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
    ),
  );

  final tokenHolder = globalTokenHolder;
  final initialConfig = ref.read(appConfigProvider);
  tokenHolder.accessToken ??= initialConfig.authToken;
  tokenHolder.refreshToken ??= initialConfig.refreshToken;
  tokenHolder.expiresAt ??= initialConfig.tokenExpiresAt;
  // 监听登录/登出但不重建 Dio；请求拦截器会动态读取 holder。
  ref.listen<(String?, String?, int?)>(
    appConfigProvider.select(
      (config) =>
          (config.authToken, config.refreshToken, config.tokenExpiresAt),
    ),
    (previous, next) {
      tokenHolder
        ..accessToken = next.$1
        ..refreshToken = next.$2
        ..expiresAt = next.$3;
    },
  );
  dio.interceptors.add(
    AuthTokenInterceptor(() => tokenHolder.accessToken, () => localeCode),
  );
  // deviceInfo 可能尚未加载完成，通过回调延迟读取。
  final deviceInfoAsync = ref.read(deviceInfoProvider);

  dio.interceptors.add(
    TokenRefreshInterceptor(
      tokenHolder: tokenHolder,
      baseUrl: baseUrl,
      refreshCoordinator: globalTokenRefreshCoordinator,
      onTokensRefreshed: (newAccess, newRefresh, expiresAt) async {
        // 登出与刷新竞态 —— 若 token 已被清空则不恢复。
        if (ref.read(appConfigProvider).authToken == null) {
          return;
        }
        await configController.persistTokens(newAccess, newRefresh, expiresAt);
      },
      getDeviceInfo: () =>
          deviceInfoAsync.whenOrNull(data: (d) => d.toApiMap()),
    ),
  );
  dio.interceptors.add(
    UnauthorizedRedirectInterceptor(
      readCurrentLocation: () {
        try {
          return router.state.uri.toString();
        } catch (_) {
          return AppRoutes.home;
        }
      },
      onUnauthorized: (redirectLocation) {
        configController.clearAuthToken();
        final currentLocation = _safeCurrentRoute(router);
        if (_isAuthRelatedRoute(currentLocation)) {
          return;
        }
        // 启动遮罩期间根 Navigator 尚未挂载，最终 401 交由 startup gate 接管。
        if (rootNavigatorKey.currentState == null) {
          return;
        }
        final loginLocation = buildLoginLocation(redirectLocation);
        Future.microtask(() {
          final latestLocation = _safeCurrentRoute(router);
          if (_isAuthRelatedRoute(latestLocation) ||
              rootNavigatorKey.currentState == null) {
            return;
          }
          router.go(loginLocation);
        });
      },
    ),
  );
  dio.interceptors.add(
    CaptchaChallengeInterceptor(dio: dio, coordinator: captchaCoordinator),
  );
  dio.interceptors.add(ErrorMessageInterceptor(ref));

  ref.onDispose(() {
    dio.close(force: true);
  });
  return dio;
});

/// 判断当前路由是否属于登录/验证码等认证相关页面，避免重复跳转。
bool _isAuthRelatedRoute(String location) {
  return location.startsWith(AppRoutes.login) ||
      location.startsWith(AppRoutes.captcha);
}

String _safeCurrentRoute(GoRouter router) {
  try {
    return router.state.uri.toString();
  } catch (_) {
    return AppRoutes.home;
  }
}
