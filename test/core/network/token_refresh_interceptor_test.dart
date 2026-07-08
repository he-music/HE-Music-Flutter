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
  });
}

class _TokenRefreshTestServer {
  _TokenRefreshTestServer._(this._server);

  final HttpServer _server;
  final Completer<void> _bothInitialRequestsSeen = Completer<void>();
  final List<String> retriedPaths = <String>[];
  final List<String> retryAuthorizations = <String>[];
  int _initialUnauthorizedCount = 0;
  int refreshRequestCount = 0;

  String get baseUrl => 'http://${_server.address.host}:${_server.port}';

  static Future<_TokenRefreshTestServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = _TokenRefreshTestServer._(server);
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
    final authorization = request.headers.value(
      HttpHeaders.authorizationHeader,
    );
    if (authorization == 'Bearer fresh-token') {
      retriedPaths.add(request.uri.path);
      retryAuthorizations.add(authorization ?? '');
      _writeJson(request.response, <String, dynamic>{'ok': true});
      return;
    }

    _initialUnauthorizedCount++;
    if (_initialUnauthorizedCount >= 2 &&
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
