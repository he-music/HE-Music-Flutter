import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/network/auth_token_interceptor.dart';

RequestOptions _options({Map<String, dynamic>? headers}) {
  return RequestOptions(path: '/test', headers: headers ?? {});
}

void main() {
  group('AuthTokenInterceptor', () {
    test('有 token 时设置双 header', () {
      final interceptor = AuthTokenInterceptor(() => 'abc123', () => 'zh');
      final options = _options();
      final handler = _TestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(options.headers['authorization'], 'Bearer abc123');
      expect(options.headers['Authorization'], 'Bearer abc123');
    });

    test('无 token（null）时跳过 token header', () {
      final interceptor = AuthTokenInterceptor(() => null, () => 'zh');
      final options = _options();
      final handler = _TestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(options.headers.containsKey('authorization'), isFalse);
      expect(options.headers.containsKey('Authorization'), isFalse);
    });

    test('空 token 时跳过 token header', () {
      final interceptor = AuthTokenInterceptor(() => '', () => 'zh');
      final options = _options();
      final handler = _TestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(options.headers.containsKey('authorization'), isFalse);
    });

    test('有 localeCode 时设置 Accept-Language', () {
      final interceptor = AuthTokenInterceptor(() => null, () => 'en');
      final options = _options();
      final handler = _TestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(options.headers['Accept-Language'], 'en;q=0.9');
    });

    test('空 localeCode 时不设置 Accept-Language', () {
      final interceptor = AuthTokenInterceptor(() => null, () => '  ');
      final options = _options();
      final handler = _TestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(options.headers.containsKey('Accept-Language'), isFalse);
    });

    test('有 token 和 localeCode 时同时设置两者', () {
      final interceptor = AuthTokenInterceptor(() => 'my-token', () => 'en');
      final options = _options();
      final handler = _TestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(options.headers['authorization'], 'Bearer my-token');
      expect(options.headers['Authorization'], 'Bearer my-token');
      expect(options.headers['Accept-Language'], 'en;q=0.9');
    });

    test('始终调用 handler.next', () {
      final interceptor = AuthTokenInterceptor(() => null, () => '');
      final handler = _TestInterceptorHandler();

      interceptor.onRequest(_options(), handler);

      expect(handler.nextCalled, isTrue);
    });
  });
}

/// 测试用 InterceptorHandler，记录是否调用了 next。
class _TestInterceptorHandler extends RequestInterceptorHandler {
  bool nextCalled = false;

  @override
  void next(RequestOptions requestOptions) {
    nextCalled = true;
  }
}
