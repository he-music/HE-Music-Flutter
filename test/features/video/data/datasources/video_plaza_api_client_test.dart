import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/features/video/data/datasources/video_plaza_api_client.dart';

void main() {
  group('VideoPlazaApiClient', () {
    group('fetchFilters', () {
      test('应正确解析 filters 列表', () async {
        final client = _createClient({
          'filters': [
            {
              'id': 'region',
              'options': [
                {'value': 'cn', 'label': '华语'},
              ],
            },
            {
              'id': 'type',
              'options': [
                {'value': 'mv', 'label': 'MV'},
              ],
            },
          ],
        });

        final result = await client.fetchFilters(platform: 'qq');

        expect(result, hasLength(2));
        expect(result.first.id, 'region');
        expect(result.first.platform, 'qq');
        expect(result.first.options.first.label, '华语');
      });

      test('filters 非 List 时应抛出 AppException', () async {
        final client = _createClient({'filters': 'bad'});

        expect(
          () => client.fetchFilters(platform: 'qq'),
          throwsA(isA<AppException>()),
        );
      });

      test('非 Map 响应应抛出 AppException', () async {
        final client = _createClient([1, 2]);

        expect(
          () => client.fetchFilters(platform: 'qq'),
          throwsA(isA<AppException>()),
        );
      });
    });

    group('fetchVideos', () {
      test('应正确解析视频列表和 hasMore', () async {
        final client = _createClient({
          'list': [
            {
              'id': 'mv-1',
              'name': 'Video 1',
              'platform': 'qq',
              'cover': 'https://img/1.jpg',
              'type': 1,
              'play_count': '100',
              'creator': 'A',
              'duration': 180,
              'description': '',
            },
          ],
          'has_more': true,
        });

        final result = await client.fetchVideos(
          platform: 'qq',
          filters: {'region': 'cn'},
        );

        expect(result.list, hasLength(1));
        expect(result.list.first.id, 'mv-1');
        expect(result.list.first.name, 'Video 1');
        expect(result.hasMore, isTrue);
      });

      test('pageIndex <= 0 应修正为 1', () async {
        Map<String, dynamic>? capturedParams;
        final client = _createClientWithCapture(
          payload: {'list': [], 'has_more': false},
          onFetch: (path, params) {
            capturedParams = params;
          },
        );

        await client.fetchVideos(platform: 'qq', filters: {}, pageIndex: -1);

        expect(capturedParams!['page_index'], 1);
      });

      test('pageSize <= 0 应修正为 50', () async {
        Map<String, dynamic>? capturedParams;
        final client = _createClientWithCapture(
          payload: {'list': [], 'has_more': false},
          onFetch: (_, params) => capturedParams = params,
        );

        await client.fetchVideos(platform: 'qq', filters: {}, pageSize: 0);

        expect(capturedParams!['page_size'], 50);
      });

      test('list 非 List 时应抛出 AppException', () async {
        final client = _createClient({'list': 'bad', 'has_more': false});

        expect(
          () => client.fetchVideos(platform: 'qq', filters: {}),
          throwsA(isA<AppException>()),
        );
      });

      test('has_more 缺失时应根据列表长度推断', () async {
        // 列表长度 >= pageSize 时 hasMore = true
        final client = _createClient({
          'list': List.generate(
            2,
            (i) => {
              'id': '$i',
              'name': 'V$i',
              'platform': 'qq',
              'cover': '',
              'type': 0,
              'play_count': '0',
              'creator': '',
              'duration': 0,
              'description': '',
            },
          ),
        });

        final result = await client.fetchVideos(
          platform: 'qq',
          filters: {},
          pageSize: 2,
        );

        expect(result.hasMore, isTrue);
      });

      test('has_more 为 num 类型应正确解析', () async {
        final client = _createClient({'list': [], 'has_more': 1});

        final result = await client.fetchVideos(platform: 'qq', filters: {});

        expect(result.hasMore, isTrue);
      });

      test('has_more 为字符串 "false" 应解析为 false', () async {
        final client = _createClient({'list': [], 'has_more': 'false'});

        final result = await client.fetchVideos(platform: 'qq', filters: {});

        expect(result.hasMore, isFalse);
      });
    });

    group('fetchMvFeed', () {
      test('应正确解析 feed 列表', () async {
        final client = _createClient({
          'list': [
            {
              'id': 'feed-1',
              'name': 'Feed Video',
              'platform': 'netease',
              'cover': '',
              'type': 0,
              'play_count': '0',
              'creator': '',
              'duration': 0,
              'description': '',
            },
          ],
          'has_more': false,
        });

        final result = await client.fetchMvFeed(
          id: 'mv-1',
          platform: 'netease',
        );

        expect(result.list, hasLength(1));
        expect(result.list.first.id, 'feed-1');
        expect(result.hasMore, isFalse);
      });

      test('pageIndex <= 0 应修正为 1', () async {
        Map<String, dynamic>? capturedParams;
        final client = _createClientWithCapture(
          payload: {'list': [], 'has_more': false},
          onFetch: (_, params) => capturedParams = params,
        );

        await client.fetchMvFeed(id: 'mv-1', platform: 'qq', pageIndex: -5);

        expect(capturedParams!['page_index'], 1);
      });

      test('list 非 List 时应抛出 AppException', () async {
        final client = _createClient({'list': null, 'has_more': false});

        expect(
          () => client.fetchMvFeed(id: '1', platform: 'qq'),
          throwsA(isA<AppException>()),
        );
      });

      test('has_more 缺失且列表非空时应返回 true', () async {
        final client = _createClient({
          'list': [
            {
              'id': '1',
              'name': 'V',
              'platform': 'qq',
              'cover': '',
              'type': 0,
              'play_count': '0',
              'creator': '',
              'duration': 0,
              'description': '',
            },
          ],
        });

        final result = await client.fetchMvFeed(id: 'mv-1', platform: 'qq');

        expect(result.hasMore, isTrue);
      });

      test('has_more 缺失且列表为空时应返回 false', () async {
        final client = _createClient({'list': []});

        final result = await client.fetchMvFeed(id: 'mv-1', platform: 'qq');

        expect(result.hasMore, isFalse);
      });
    });
  });
}

VideoPlazaApiClient _createClient(dynamic payload) {
  final dio = Dio();
  dio.httpClientAdapter = _MockAdapter(payload);
  return VideoPlazaApiClient(dio);
}

VideoPlazaApiClient _createClientWithCapture({
  required dynamic payload,
  required void Function(String path, Map<String, dynamic> params) onFetch,
}) {
  final dio = Dio();
  dio.httpClientAdapter = _CapturingAdapter(payload, onFetch);
  return VideoPlazaApiClient(dio);
}

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._payload);

  final dynamic _payload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(_payload),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this._payload, this._onFetch);

  final dynamic _payload;
  final void Function(String path, Map<String, dynamic> params) _onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _onFetch(options.path, options.queryParameters);
    return ResponseBody.fromString(
      jsonEncode(_payload),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
