import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/network/client_instance_id_store.dart';
import 'package:he_music_flutter/core/network/client_instance_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'random installation identity persists across stores and concurrent loads',
    () async {
      SharedPreferences.setMockInitialValues({'device_id': 'jwt-device'});
      final store = ClientInstanceIdStore();
      final values = await Future.wait(List.generate(8, (_) => store.load()));
      expect(values.toSet(), hasLength(1));
      expect(ClientInstanceIdStore.isValid(values.first), isTrue);
      expect(await ClientInstanceIdStore().load(), values.first);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('device_id'), 'jwt-device');
    },
  );

  test(
    'invalid saved identities are replaced; failed storage can retry',
    () async {
      for (final value in ['', 'a b', 'a\nb', '中文', 'x' * 129]) {
        SharedPreferences.setMockInitialValues({
          ClientInstanceIdStore.storageKey: value,
        });
        final id = await ClientInstanceIdStore().load();
        expect(ClientInstanceIdStore.isValid(id), isTrue);
        expect(id, isNot(value));
      }
      var attempts = 0;
      final store = ClientInstanceIdStore(
        loadPreferences: () async {
          if (++attempts == 1) throw StateError('storage unavailable');
          return SharedPreferences.getInstance();
        },
      );
      await expectLater(store.load(), throwsStateError);
      expect(ClientInstanceIdStore.isValid(await store.load()), isTrue);
      expect(attempts, 2);
    },
  );

  test('only backend origin and base path receive a valid header', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://he.example/api'));
    final requests = <RequestOptions>[];
    dio.interceptors.add(
      ClientInstanceInterceptor(
        baseUrl: dio.options.baseUrl,
        loadId: () async => 'installation-123',
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(requestOptions: options, data: {}, statusCode: 200),
          );
        },
      ),
    );
    for (final url in [
      '/v1/platforms',
      'https://cdn.example/api/cover',
      'https://he.example/api-other/song',
      'http://he.example/api/song',
      'https://he.example:444/api/song',
    ]) {
      await dio.get<dynamic>(
        url,
        options: Options(headers: {'x-client-instance-id': 'stale'}),
      );
    }
    expect(
      requests.first.headers[ClientInstanceInterceptor.headerName],
      'installation-123',
    );
    expect(requests.first.followRedirects, isFalse);
    for (final request in requests.skip(1)) {
      expect(
        request.headers.keys.where(
          (key) => key.toLowerCase() == 'x-client-instance-id',
        ),
        isEmpty,
      );
    }
    dio.close();
  });

  test(
    'storage failure permits backend fallback without blocking requests',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://he.example'));
      dio.interceptors.add(
        ClientInstanceInterceptor(
          baseUrl: dio.options.baseUrl,
          loadId: () async => throw StateError('storage unavailable'),
        ),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(
              options.headers[ClientInstanceInterceptor.headerName],
              isNull,
            );
            handler.resolve(Response(requestOptions: options, statusCode: 200));
          },
        ),
      );
      expect((await dio.get<dynamic>('/v1/platforms')).statusCode, 200);
      dio.close();
    },
  );

  test(
    'backend redirects never forward installation identity to a CDN',
    () async {
      final cdn = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final backend = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var cdnRequests = 0;
      cdn.listen((request) {
        cdnRequests++;
        request.response.close();
      });
      backend.listen((request) {
        expect(
          request.headers.value('X-Client-Instance-ID'),
          'installation-123',
        );
        request.response
          ..statusCode = 302
          ..headers.set('location', 'http://127.0.0.1:${cdn.port}/media');
        request.response.close();
      });
      final baseUrl = 'http://127.0.0.1:${backend.port}';
      final dio = Dio(BaseOptions(baseUrl: baseUrl));
      dio.interceptors.add(
        ClientInstanceInterceptor(
          baseUrl: baseUrl,
          loadId: () async => 'installation-123',
        ),
      );
      try {
        await expectLater(
          dio.get<dynamic>('/v1/song/cover'),
          throwsA(isA<DioException>()),
        );
        expect(cdnRequests, 0);
      } finally {
        dio.close(force: true);
        await backend.close(force: true);
        await cdn.close(force: true);
      }
    },
  );
}
