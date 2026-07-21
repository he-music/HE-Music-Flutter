import 'dart:async';

import 'package:dio/dio.dart';

/// 可变的 token 引用持有者。
/// TokenRefreshInterceptor 和 apiDioProvider 共享同一个实例，
/// 保证闭包读到的始终是最新值。
class TokenHolder {
  TokenHolder({this.accessToken, this.refreshToken, this.expiresAt});

  String? accessToken;
  String? refreshToken;
  int? expiresAt;
}

typedef TokensRefreshedCallback =
    FutureOr<void> Function(
      String accessToken,
      String refreshToken,
      int expiresAt,
    );

/// 负责跨 Dio 实例合并并发 refresh，并同步最新 token。
class TokenRefreshCoordinator {
  TokenRefreshCoordinator(this.tokenHolder);

  final TokenHolder tokenHolder;
  Future<String?>? _ongoingRefresh;

  Future<String?> refresh({
    required String baseUrl,
    required TokensRefreshedCallback onTokensRefreshed,
    Map<String, dynamic>? Function()? getDeviceInfo,
  }) {
    final ongoingRefresh = _ongoingRefresh;
    if (ongoingRefresh != null) {
      return ongoingRefresh;
    }

    final refreshToken = tokenHolder.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return Future<String?>.value();
    }

    final refreshFuture = _doRefresh(
      baseUrl: baseUrl,
      refreshToken: refreshToken,
      onTokensRefreshed: onTokensRefreshed,
      getDeviceInfo: getDeviceInfo,
    );
    _ongoingRefresh = refreshFuture;
    unawaited(
      refreshFuture.whenComplete(() {
        if (identical(_ongoingRefresh, refreshFuture)) {
          _ongoingRefresh = null;
        }
      }),
    );
    return refreshFuture;
  }

  Future<String?> _doRefresh({
    required String baseUrl,
    required String refreshToken,
    required TokensRefreshedCallback onTokensRefreshed,
    Map<String, dynamic>? Function()? getDeviceInfo,
  }) async {
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        responseType: ResponseType.json,
      ),
    );

    try {
      final requestData = <String, dynamic>{'refresh_token': refreshToken};
      final deviceInfo = getDeviceInfo?.call();
      if (deviceInfo != null) {
        requestData['device_info'] = deviceInfo;
      }

      final response = await refreshDio.post(
        '/v1/auth/token/refresh',
        data: requestData,
      );
      final data = response.data;
      if (data is! Map) {
        return null;
      }

      final newAccessToken = '${data['access_token'] ?? ''}'.trim();
      final newRefreshToken = '${data['refresh_token'] ?? ''}'.trim();
      final expiresAt = data['expires_at'];
      if (newAccessToken.isEmpty) {
        return null;
      }

      final effectiveRefresh = newRefreshToken.isNotEmpty
          ? newRefreshToken
          : refreshToken;
      final effectiveExpiresAt = expiresAt is int ? expiresAt : 0;
      // 登出或重新登录会替换 refresh token，旧请求不得恢复已经失效的会话。
      if (tokenHolder.refreshToken != refreshToken) {
        return null;
      }
      tokenHolder.accessToken = newAccessToken;
      tokenHolder.refreshToken = effectiveRefresh;
      tokenHolder.expiresAt = effectiveExpiresAt;
      await onTokensRefreshed(
        newAccessToken,
        effectiveRefresh,
        effectiveExpiresAt,
      );
      return newAccessToken;
    } catch (_) {
      return null;
    } finally {
      refreshDio.close(force: true);
    }
  }
}

/// 普通 API 与后台音频请求共享同一份实时 token 和 refresh Future。
final globalTokenHolder = TokenHolder();
final globalTokenRefreshCoordinator = TokenRefreshCoordinator(
  globalTokenHolder,
);

/// 拦截 401 响应，自动使用 refresh_token 换取新的 token 对。
/// 刷新失败时将错误传递给下游（UnauthorizedRedirectInterceptor 处理登出）。
class TokenRefreshInterceptor extends Interceptor {
  TokenRefreshInterceptor({
    required this.tokenHolder,
    required this.baseUrl,
    required this.onTokensRefreshed,
    TokenRefreshCoordinator? refreshCoordinator,
    this.getDeviceInfo,
  }) : assert(
         refreshCoordinator == null ||
             identical(refreshCoordinator.tokenHolder, tokenHolder),
       ),
       _refreshCoordinator =
           refreshCoordinator ?? TokenRefreshCoordinator(tokenHolder);

  final TokenHolder tokenHolder;
  final String baseUrl;
  final TokensRefreshedCallback onTokensRefreshed;
  final TokenRefreshCoordinator _refreshCoordinator;

  /// 返回当前设备信息 Map（对应 proto DeviceInfo），用于刷新请求。
  final Map<String, dynamic>? Function()? getDeviceInfo;

  /// 不需要尝试刷新的接口路径。
  static final _excludedPaths = RegExp(
    r'/(login|token/refresh|auth/result|auth/qr/result|auth/logout)\b',
  );

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final path = err.requestOptions.path;
    if (_excludedPaths.hasMatch(path)) {
      return handler.next(err);
    }

    // 已经重试过一次，不再刷新。
    if (err.requestOptions.extra['tokenRefreshed'] == true) {
      return handler.next(err);
    }

    if (tokenHolder.refreshToken?.isNotEmpty != true) {
      return handler.next(err);
    }

    _refreshCoordinator
        .refresh(
          baseUrl: baseUrl,
          onTokensRefreshed: onTokensRefreshed,
          getDeviceInfo: getDeviceInfo,
        )
        .then((newToken) {
          if (newToken == null || newToken.isEmpty) {
            handler.next(err);
            return;
          }
          _retryWithToken(err.requestOptions, newToken)
              .then((response) {
                handler.resolve(response);
              })
              .catchError((Object _) {
                handler.next(err);
              });
        })
        .catchError((Object _) {
          handler.next(err);
        });
  }

  Future<Response<dynamic>> _retryWithToken(
    RequestOptions original,
    String newToken,
  ) async {
    final retryDio = Dio(
      BaseOptions(
        baseUrl: original.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
      ),
    );
    try {
      original.headers['authorization'] = 'Bearer $newToken';
      original.headers['Authorization'] = 'Bearer $newToken';
      original.extra['tokenRefreshed'] = true;
      return await retryDio.fetch<dynamic>(original);
    } finally {
      retryDio.close(force: true);
    }
  }
}
