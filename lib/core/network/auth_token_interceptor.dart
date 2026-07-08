import 'package:dio/dio.dart';

class AuthTokenInterceptor extends Interceptor {
  AuthTokenInterceptor(this._readToken, this._readLocaleCode);

  final String? Function() _readToken;
  final String Function() _readLocaleCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _readToken();
    final localeCode = _readLocaleCode().trim();
    if (token != null && token.isNotEmpty) {
      // 后端要求使用小写 header: authorization
      // 同时保留 Authorization 兼容不同网关/代理行为。
      options.headers['authorization'] = 'Bearer $token';
      options.headers['Authorization'] = 'Bearer $token';
    }
    if (localeCode.isNotEmpty) {
      options.headers['Accept-Language'] = '$localeCode;q=0.9';
    }
    handler.next(options);
  }
}
