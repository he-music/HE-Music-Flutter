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
      options.headers['Authorization'] = 'Bearer $token';
    }
    if (localeCode.isNotEmpty) {
      options.headers['Accept-Language'] = '$localeCode;q=0.9';
    }
    handler.next(options);
  }
}
