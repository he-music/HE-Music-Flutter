import 'package:dio/dio.dart';

final _authExcludedPaths = RegExp(
  r'/(login|token/refresh|auth/result|auth/qr/result|auth/logout)\b',
);

/// 启动恢复与请求拦截器共用认证失败判断，保留刷新期间临时失败的会话。
bool shouldRedirectUnauthorized(DioException error) {
  final request = error.requestOptions;
  return error.response?.statusCode == 401 &&
      !_authExcludedPaths.hasMatch(request.path.trim().toLowerCase()) &&
      request.extra['skipUnauthorizedRedirect'] != true &&
      request.extra['tokenRefreshed'] != true;
}

class UnauthorizedRedirectInterceptor extends Interceptor {
  UnauthorizedRedirectInterceptor({
    required this.readCurrentLocation,
    required this.onUnauthorized,
  });

  final String Function() readCurrentLocation;
  final void Function(String redirectLocation) onUnauthorized;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (shouldRedirectUnauthorized(err)) {
      onUnauthorized(readCurrentLocation());
    }
    handler.next(err);
  }
}
