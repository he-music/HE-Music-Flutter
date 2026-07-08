import 'dart:async';

import 'package:dio/dio.dart';

/// 可变的 token 引用持有者。
/// TokenRefreshInterceptor 和 apiDioProvider 共享同一个实例，
/// 保证闭包读到的始终是最新值。
class TokenHolder {
  TokenHolder({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;
}

/// 全局共享的 TokenHolder 实例。
/// apiDioProvider、TokenRefreshInterceptor、HeAudioHandler 共用同一个实例，
/// 保证 token 刷新后所有网络层立即可见。
final globalTokenHolder = TokenHolder();

/// 拦截 401 响应，自动使用 refresh_token 换取新的 token 对。
/// 刷新失败时将错误传递给下游（UnauthorizedRedirectInterceptor 处理登出）。
class TokenRefreshInterceptor extends Interceptor {
  TokenRefreshInterceptor({
    required this.tokenHolder,
    required this.baseUrl,
    required this.onTokensRefreshed,
    this.getDeviceInfo,
  });

  final TokenHolder tokenHolder;
  final String baseUrl;
  final void Function(String accessToken, String refreshToken, int expiresAt)
  onTokensRefreshed;

  /// 返回当前设备信息 Map（对应 proto DeviceInfo），用于刷新请求。
  final Map<String, dynamic>? Function()? getDeviceInfo;

  /// 防止并发刷新：多个 401 共享同一次刷新+重试流程。
  /// Completer 在整个流程（刷新 + 重试）完成后才 complete。
  Completer<void>? _ongoingRefresh;

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

    final refreshToken = tokenHolder.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return handler.next(err);
    }

    // 并发保护：多个 401 共享同一次刷新，后续请求等待完成后使用新 token。
    if (_ongoingRefresh != null) {
      final ongoingRefresh = _ongoingRefresh!;
      ongoingRefresh.future
          .then((_) {
            final newToken = tokenHolder.accessToken;
            if (newToken == null || newToken.isEmpty) {
              handler.next(err);
              return;
            }
            _retryWithToken(err.requestOptions, newToken)
                .then((response) {
                  handler.resolve(response);
                })
                .catchError((Object e) {
                  handler.next(err);
                });
          })
          .catchError((Object _) {
            handler.next(err);
          });
      return;
    }

    final refreshCompleter = Completer<void>();
    _ongoingRefresh = refreshCompleter;
    void completeRefresh() {
      if (!refreshCompleter.isCompleted) {
        refreshCompleter.complete();
      }
    }

    _doRefresh(refreshToken)
        .then((newToken) {
          if (newToken == null || newToken.isEmpty) {
            handler.next(err);
            completeRefresh();
            return Future<void>.value();
          }
          return _retryWithToken(err.requestOptions, newToken)
              .then((response) {
                handler.resolve(response);
              })
              .catchError((Object e) {
                handler.next(err);
              })
              .whenComplete(() {
                completeRefresh();
              });
        })
        .catchError((Object _) {
          handler.next(err);
          completeRefresh();
        })
        .whenComplete(() {
          if (identical(_ongoingRefresh, refreshCompleter)) {
            _ongoingRefresh = null;
          }
        });
  }

  /// 调用后端刷新接口，返回新 access_token。
  /// 成功时同步更新 tokenHolder 并持久化到 SharedPreferences。
  Future<String?> _doRefresh(String refreshToken) async {
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

      // 同步更新可变引用，后续请求立即使用新 token。
      tokenHolder.accessToken = newAccessToken;
      tokenHolder.refreshToken = effectiveRefresh;

      // 通知 Riverpod 持久化。
      onTokensRefreshed(newAccessToken, effectiveRefresh, effectiveExpiresAt);

      return newAccessToken;
    } catch (_) {
      return null;
    } finally {
      refreshDio.close(force: true);
    }
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
