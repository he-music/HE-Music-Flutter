import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/network/auth_token_interceptor.dart';
import 'package:he_music_flutter/core/network/token_refresh_interceptor.dart';

void main() {
  group('TokenRefreshInterceptor', () {
    test('并发 401 应共享一次刷新并都用新 token 重试成功', () async {
      final server = await _TokenRefreshTestServer.start();
      final tokenHolder = TokenHolder(
        accessToken: 'expired-token',
        refreshToken: 'refresh-token',
      );
      final refreshedTokens = <String>[];
      final dio = Dio(
        BaseOptions(baseUrl: server.baseUrl, responseType: ResponseType.json),
      );
      dio.interceptors.add(
        AuthTokenInterceptor(() => tokenHolder.accessToken, () => 'zh'),
      );
      dio.interceptors.add(
        TokenRefreshInterceptor(
          tokenHolder: tokenHolder,
          baseUrl: server.baseUrl,
          onTokensRefreshed: (accessToken, refreshToken, _) {
            refreshedTokens.add('$accessToken|$refreshToken');
          },
        ),
      );

      try {
        final responses = await Future.wait(<Future<Response<dynamic>>>[
          dio.get('/v1/user/info'),
          dio.get('/v1/platforms'),
        ]).timeout(const Duration(seconds: 1));

        expect(responses.map((item) => item.statusCode), everyElement(200));
        expect(server.refreshRequestCount, 1);
        expect(
          server.retriedPaths,
          containsAll(<String>['/v1/user/info', '/v1/platforms']),
        );
        expect(server.retryAuthorizations, everyElement('Bearer fresh-token'));
        expect(refreshedTokens, <String>['fresh-token|fresh-refresh-token']);
      } finally {
        dio.close(force: true);
        await server.close();
      }
    });

    test('不同 Dio 实例的并发 401 应共享一次刷新', () async {
      final server = await _TokenRefreshTestServer.start();
      final tokenHolder = TokenHolder(
        accessToken: 'expired-token',
        refreshToken: 'refresh-token',
      );
      final coordinator = TokenRefreshCoordinator(tokenHolder);
      final refreshedTokens = <String>[];
      final firstDio = _createDio(
        server.baseUrl,
        tokenHolder,
        coordinator,
        refreshedTokens,
      );
      final secondDio = _createDio(
        server.baseUrl,
        tokenHolder,
        coordinator,
        refreshedTokens,
      );

      try {
        final responses = await Future.wait(<Future<Response<dynamic>>>[
          firstDio.get('/v1/user/info'),
          secondDio.get('/v1/platforms'),
        ]).timeout(const Duration(seconds: 1));

        expect(responses.map((item) => item.statusCode), everyElement(200));
        expect(server.refreshRequestCount, 1);
        expect(server.retriedPaths, hasLength(2));
        expect(refreshedTokens, <String>['fresh-token|fresh-refresh-token']);
      } finally {
        firstDio.close(force: true);
        secondDio.close(force: true);
        await server.close();
      }
    });

    test('新 token 重放仍返回 401 时不应再次刷新', () async {
      final server = await _TokenRefreshTestServer.start(
        initialRequestTarget: 1,
        rejectFreshToken: true,
      );
      final tokenHolder = TokenHolder(
        accessToken: 'expired-token',
        refreshToken: 'refresh-token',
      );
      final dio = _createDio(
        server.baseUrl,
        tokenHolder,
        TokenRefreshCoordinator(tokenHolder),
        <String>[],
      );

      try {
        await expectLater(
          dio.get<dynamic>('/v1/user/info'),
          throwsA(
            isA<DioException>().having(
              (error) => error.response?.statusCode,
              'statusCode',
              401,
            ),
          ),
        );
        expect(server.refreshRequestCount, 1);
        expect(server.protectedRequestCount, 2);
      } finally {
        dio.close(force: true);
        await server.close();
      }
    });
  });
}

Dio _createDio(
  String baseUrl,
  TokenHolder tokenHolder,
  TokenRefreshCoordinator coordinator,
  List<String> refreshedTokens,
) {
  final dio = Dio(
    BaseOptions(baseUrl: baseUrl, responseType: ResponseType.json),
  );
  dio.interceptors.add(
    AuthTokenInterceptor(() => tokenHolder.accessToken, () => 'zh'),
  );
  dio.interceptors.add(
    TokenRefreshInterceptor(
      tokenHolder: tokenHolder,
      baseUrl: baseUrl,
      refreshCoordinator: coordinator,
      onTokensRefreshed: (accessToken, refreshToken, _) {
        refreshedTokens.add('$accessToken|$refreshToken');
      },
    ),
  );
  return dio;
}

class _TokenRefreshTestServer {
  _TokenRefreshTestServer._(
    this._server, {
    required this.initialRequestTarget,
    required this.rejectFreshToken,
  });

  final HttpServer _server;
  final int initialRequestTarget;
  final bool rejectFreshToken;
  final Completer<void> _bothInitialRequestsSeen = Completer<void>();
  final List<String> retriedPaths = <String>[];
  final List<String> retryAuthorizations = <String>[];
  int _initialUnauthorizedCount = 0;
  int refreshRequestCount = 0;
  int protectedRequestCount = 0;

  String get baseUrl => 'http://${_server.address.host}:${_server.port}';

  static Future<_TokenRefreshTestServer> start({
    int initialRequestTarget = 2,
    bool rejectFreshToken = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _TokenRefreshTestServer._(
      server,
      initialRequestTarget: initialRequestTarget,
      rejectFreshToken: rejectFreshToken,
    );
    server.listen(fixture._handleRequest);
    return fixture;
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    if (path == '/v1/auth/token/refresh') {
      await _handleRefresh(request);
      return;
    }
    await _handleProtectedRequest(request);
  }

  Future<void> _handleRefresh(HttpRequest request) async {
    refreshRequestCount++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _writeJson(request.response, <String, dynamic>{
      'access_token': 'fresh-token',
      'refresh_token': 'fresh-refresh-token',
      'expires_at': 123,
    });
  }

  Future<void> _handleProtectedRequest(HttpRequest request) async {
    protectedRequestCount++;
    final authorization = request.headers.value(
      HttpHeaders.authorizationHeader,
    );
    if (authorization == 'Bearer fresh-token' && !rejectFreshToken) {
      retriedPaths.add(request.uri.path);
      retryAuthorizations.add(authorization ?? '');
      _writeJson(request.response, <String, dynamic>{'ok': true});
      return;
    }

    _initialUnauthorizedCount++;
    if (_initialUnauthorizedCount >= initialRequestTarget &&
        !_bothInitialRequestsSeen.isCompleted) {
      _bothInitialRequestsSeen.complete();
    }
    await _bothInitialRequestsSeen.future;
    _writeJson(request.response, <String, dynamic>{
      'error': 'expired',
    }, statusCode: HttpStatus.unauthorized);
  }

  void _writeJson(
    HttpResponse response,
    Map<String, dynamic> payload, {
    int statusCode = HttpStatus.ok,
  }) {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));
    unawaited(response.close());
  }
}
