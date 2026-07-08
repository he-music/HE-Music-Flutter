import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/network/unauthorized_redirect_interceptor.dart';

DioException _dioException(int? statusCode, {required String path}) {
  return DioException(
    requestOptions: RequestOptions(path: path),
    response: statusCode != null
        ? Response(
            requestOptions: RequestOptions(path: path),
            statusCode: statusCode,
          )
        : null,
    type: DioExceptionType.badResponse,
  );
}

void main() {
  group('UnauthorizedRedirectInterceptor', () {
    test('401 + 非 login 路径触发 onUnauthorized', () {
      String? redirectedLocation;
      final interceptor = UnauthorizedRedirectInterceptor(
        readCurrentLocation: () => '/home',
        onUnauthorized: (loc) => redirectedLocation = loc,
      );
      final handler = _TestErrorInterceptorHandler();

      interceptor.onError(_dioException(401, path: '/v1/song/url'), handler);

      expect(redirectedLocation, '/home');
    });

    test('401 + /v1/login 路径不触发 onUnauthorized', () {
      String? redirectedLocation;
      final interceptor = UnauthorizedRedirectInterceptor(
        readCurrentLocation: () => '/home',
        onUnauthorized: (loc) => redirectedLocation = loc,
      );
      final handler = _TestErrorInterceptorHandler();

      interceptor.onError(_dioException(401, path: '/v1/login'), handler);

      expect(redirectedLocation, isNull);
    });

    test('401 + 以 /v1/login 结尾的路径不触发', () {
      String? redirectedLocation;
      final interceptor = UnauthorizedRedirectInterceptor(
        readCurrentLocation: () => '/home',
        onUnauthorized: (loc) => redirectedLocation = loc,
      );
      final handler = _TestErrorInterceptorHandler();

      interceptor.onError(
        _dioException(401, path: 'https://api.example.com/v1/login'),
        handler,
      );

      expect(redirectedLocation, isNull);
    });

    test('非 401 状态码不触发 onUnauthorized', () {
      String? redirectedLocation;
      final interceptor = UnauthorizedRedirectInterceptor(
        readCurrentLocation: () => '/home',
        onUnauthorized: (loc) => redirectedLocation = loc,
      );
      final handler = _TestErrorInterceptorHandler();

      interceptor.onError(_dioException(500, path: '/v1/song/url'), handler);

      expect(redirectedLocation, isNull);
    });

    test('response 为 null 时不触发 onUnauthorized', () {
      String? redirectedLocation;
      final interceptor = UnauthorizedRedirectInterceptor(
        readCurrentLocation: () => '/home',
        onUnauthorized: (loc) => redirectedLocation = loc,
      );
      final handler = _TestErrorInterceptorHandler();

      interceptor.onError(_dioException(null, path: '/v1/song/url'), handler);

      expect(redirectedLocation, isNull);
    });

    test('始终调用 handler.next', () {
      final interceptor = UnauthorizedRedirectInterceptor(
        readCurrentLocation: () => '/home',
        onUnauthorized: (_) {},
      );
      final handler = _TestErrorInterceptorHandler();

      interceptor.onError(_dioException(401, path: '/v1/song/url'), handler);

      expect(handler.nextCalled, isTrue);
    });
  });
}

class _TestErrorInterceptorHandler extends ErrorInterceptorHandler {
  bool nextCalled = false;

  @override
  void next(DioException err) {
    nextCalled = true;
  }
}
