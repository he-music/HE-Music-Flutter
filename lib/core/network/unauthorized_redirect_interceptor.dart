import 'package:dio/dio.dart';

class UnauthorizedRedirectInterceptor extends Interceptor {
  UnauthorizedRedirectInterceptor({
    required this.readCurrentLocation,
    required this.onUnauthorized,
  });

  final String Function() readCurrentLocation;
  final void Function(String redirectLocation) onUnauthorized;

  static final _authExcludedPaths = RegExp(
    r'/(login|token/refresh|auth/result|auth/qr/result|auth/logout)\b',
  );

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    if (statusCode == 401 &&
        !_isLoginRequest(err.requestOptions.path) &&
        err.requestOptions.extra['tokenRefreshed'] != true) {
      onUnauthorized(readCurrentLocation());
    }
    handler.next(err);
  }

  bool _isLoginRequest(String path) {
    final normalized = path.trim().toLowerCase();
    return _authExcludedPaths.hasMatch(normalized);
  }
}
