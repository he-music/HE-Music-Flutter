import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/features/home/data/datasources/home_page_api_client.dart';

void main() {
  for (final discover in [false, true]) {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('${discover ? '发现' : '推荐'}页 $type 后重试成功且不弹中间错误', () async {
        final adapter = _FlakyAdapter(type: type, failures: 1);
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final silentErrors = <bool>[];
        dio.interceptors.add(
          InterceptorsWrapper(
            onError: (error, handler) {
              silentErrors.add(
                error.requestOptions.extra['silentErrorMessage'] == true,
              );
              handler.next(error);
            },
          ),
        );
        final client = HomePageApiClient(dio);

        final result = discover
            ? await client.fetchDiscoverPage(platformId: 'qq')
            : await client.fetchRecommendPage(platformId: 'qq', pageIndex: 2);

        expect(result.sections, isEmpty);
        expect(adapter.requests, hasLength(2));
        expect(
          adapter.requests.map((request) => request.path),
          everyElement(discover ? '/v1/page/discover' : '/v1/page/recommend'),
        );
        expect(
          adapter.requests.map((request) => request.queryParameters),
          everyElement(<String, dynamic>{
            'platform': 'qq',
            if (!discover) 'page_index': 2,
          }),
        );
        expect(silentErrors, [true]);
      });
    }
  }

  test('首页持续连接失败最多请求三次并返回最后的异常', () async {
    final adapter = _FlakyAdapter(
      type: DioExceptionType.connectionError,
      failures: 10,
    );
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));

    await expectLater(
      HomePageApiClient(dio).fetchRecommendPage(platformId: 'qq', pageIndex: 1),
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.connectionError,
        ),
      ),
    );
    expect(adapter.requests, hasLength(3));
  });

  for (final type in [
    DioExceptionType.badResponse,
    DioExceptionType.badCertificate,
    DioExceptionType.cancel,
    DioExceptionType.unknown,
  ]) {
    test('首页 $type 不进行传输重试', () async {
      final adapter = _FlakyAdapter(type: type, failures: 1);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));

      await expectLater(
        HomePageApiClient(dio).fetchDiscoverPage(platformId: 'qq'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, hasLength(1));
    });
  }

  test('首页返回无效内容时不重复请求', () async {
    final adapter = _FlakyAdapter(
      type: DioExceptionType.connectionError,
      failures: 0,
      payload: const <String, dynamic>{},
    );
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));

    await expectLater(
      HomePageApiClient(dio).fetchDiscoverPage(platformId: 'qq'),
      throwsA(isA<AppException>()),
    );
    expect(adapter.requests, hasLength(1));
  });
}

class _FlakyAdapter implements HttpClientAdapter {
  _FlakyAdapter({
    required this.type,
    required this.failures,
    this.payload = const <String, dynamic>{'sections': <dynamic>[]},
  });

  final DioExceptionType type;
  final int failures;
  final Map<String, dynamic> payload;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requests.length <= failures) {
      throw DioException(
        requestOptions: options,
        type: type,
        response: type == DioExceptionType.badResponse
            ? Response<dynamic>(requestOptions: options, statusCode: 401)
            : null,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
