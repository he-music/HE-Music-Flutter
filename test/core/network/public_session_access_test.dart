import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/core/network/api_dio_provider.dart';
import 'package:he_music_flutter/core/network/client_instance_interceptor.dart';
import 'package:he_music_flutter/core/network/token_refresh_interceptor.dart';
import 'package:he_music_flutter/core/network/unauthorized_redirect_interceptor.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_playback_api_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    globalTokenHolder
      ..accessToken = null
      ..refreshToken = null
      ..expiresAt = null
      ..sessionRevision = 0;
  });

  for (final initialToken in [null, 'old-account']) {
    test(
      'current 401 from $initialToken requires login without anonymous retry',
      () async {
        final container = ProviderContainer(
          overrides: [appConfigProvider.overrideWith(_Config.new)],
        );
        addTearDown(container.dispose);
        if (initialToken != null) {
          container.read(appConfigProvider.notifier).setAuthToken(initialToken);
        }
        final dio = container.read(apiDioProvider);
        final adapter = _Adapter();
        dio.httpClientAdapter = adapter;
        final request = dio.get<dynamic>(
          '/v1/platforms',
          options: Options(extra: {'silentErrorMessage': true}),
        );
        final failed = expectLater(
          request,
          throwsA(
            isA<DioException>().having(
              shouldRedirectUnauthorized,
              'requires login',
              true,
            ),
          ),
        );
        await adapter.started.future;
        adapter.response.complete(
          ResponseBody.fromString(
            '{}',
            401,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          ),
        );
        await failed;
        expect(container.read(appConfigProvider).authToken, isNull);
        expect(adapter.requests, hasLength(1));
      },
    );
    test('delayed 401 from $initialToken cannot clear a new login', () async {
      final container = ProviderContainer(
        overrides: [appConfigProvider.overrideWith(_Config.new)],
      );
      addTearDown(container.dispose);
      final config = container.read(appConfigProvider.notifier);
      if (initialToken != null) config.setAuthToken(initialToken);
      final dio = container.read(apiDioProvider);
      final adapter = _Adapter();
      dio.httpClientAdapter = adapter;
      final request = dio.get<dynamic>(
        '/v1/platforms',
        options: Options(extra: {'silentErrorMessage': true}),
      );
      final failed = expectLater(request, throwsA(isA<DioException>()));
      await adapter.started.future;
      config.setAuthToken('new-account');
      adapter.response.complete(
        ResponseBody.fromString(
          '{}',
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      await failed;
      expect(container.read(appConfigProvider).authToken, 'new-account');
      expect(globalTokenHolder.accessToken, 'new-account');
      expect(adapter.requests, hasLength(1));
    });
  }

  test(
    'anonymous platform, search, lyrics and both foreground playback entries share identity',
    () async {
      final container = ProviderContainer(
        overrides: [appConfigProvider.overrideWith(_Config.new)],
      );
      addTearDown(container.dispose);
      final requests = <RequestOptions>[];
      void respond(RequestOptions options, RequestInterceptorHandler handler) {
        requests.add(options);
        final data = switch (options.path) {
          '/v1/platforms' => {
            'list': [
              {'id': 'public', 'name': 'Public', 'status': 1},
            ],
          },
          '/v1/song/search' => {'list': []},
          '/v1/song/url' => {'url': 'https://cdn.example/song.mp3'},
          _ => {'lyric': '[00:00]hello'},
        };
        handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: data),
        );
      }

      final dio = container.read(apiDioProvider);
      dio.interceptors.add(InterceptorsWrapper(onRequest: respond));
      final api = OnlineApiClient(dio);
      await api.fetchPlatforms();
      await api.searchSongs(keyword: 'hello', platform: 'public');
      await api.fetchSongUrl(songId: 'song', platform: 'public');
      await api.fetchSongLyric(songId: 'song', platform: 'public');
      container
          .read(playerPlaybackDioProvider)
          .interceptors
          .add(InterceptorsWrapper(onRequest: respond));
      await container
          .read(playerPlaybackApiClientProvider)
          .fetchSongUrl(songId: 'song', platform: 'public');
      expect(requests.map((request) => request.path), [
        '/v1/platforms',
        '/v1/song/search',
        '/v1/song/url',
        '/v1/song/lyric',
        '/v1/song/url',
      ]);
      expect(
        requests
            .map(
              (request) =>
                  request.headers[ClientInstanceInterceptor.headerName],
            )
            .toSet(),
        hasLength(1),
      );
      expect(
        requests.first.headers[ClientInstanceInterceptor.headerName],
        isNotEmpty,
      );
      expect(
        requests.every(
          (request) => !request.headers.containsKey('Authorization'),
        ),
        isTrue,
      );
      expect(
        requests.any((request) => request.path.startsWith('/v1/user')),
        isFalse,
      );
    },
  );
}

class _Config extends AppConfigController {
  @override
  AppConfigState build() =>
      AppConfigState.initial.copyWith(apiBaseUrl: 'https://he.example');
}

class _Adapter implements HttpClientAdapter {
  final started = Completer<void>();
  final response = Completer<ResponseBody>();
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    started.complete();
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}
