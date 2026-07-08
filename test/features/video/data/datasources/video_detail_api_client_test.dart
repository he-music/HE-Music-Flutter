import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/features/video/data/datasources/video_detail_api_client.dart';
import 'package:he_music_flutter/features/video/domain/entities/video_detail_request.dart';

void main() {
  group('VideoDetailApiClient', () {
    group('fetchDetail', () {
      test('应正确解析完整响应', () async {
        final client = _createClient({
          'name': 'Test MV',
          'cover': 'https://img/cover.jpg',
          'type': 1,
          'play_count': '12345',
          'creator': 'Artist',
          'duration': 200,
          'description': 'A test MV',
          'links': [
            {
              'name': 'HD',
              'quality': 1080,
              'format': 'mp4',
              'size': '50MB',
              'url': 'https://cdn/1080.mp4',
            },
          ],
        });

        final result = await client.fetchDetail(
          const VideoDetailRequest(
            id: 'mv-1',
            platform: 'qq',
            title: 'Fallback Title',
          ),
        );

        expect(result.info.name, 'Test MV');
        expect(result.info.cover, 'https://img/cover.jpg');
        expect(result.info.type, 1);
        expect(result.info.playCount, '12345');
        expect(result.info.creator, 'Artist');
        expect(result.info.duration, 200);
        expect(result.info.description, 'A test MV');
        expect(result.info.platform, 'qq');
        expect(result.info.id, 'mv-1');
        expect(result.links, hasLength(1));
        expect(result.links.first.quality, 1080);
        expect(result.links.first.url, 'https://cdn/1080.mp4');
      });

      test('应使用 name 字段作为标题', () async {
        final client = _createClient({'name': 'Actual Title', 'links': []});

        final result = await client.fetchDetail(
          const VideoDetailRequest(
            id: '1',
            platform: 'netease',
            title: 'Fallback',
          ),
        );

        expect(result.info.name, 'Actual Title');
      });

      test('name 为空时应使用 fallback 标题', () async {
        final client = _createClient({'name': '', 'links': []});

        final result = await client.fetchDetail(
          const VideoDetailRequest(
            id: '1',
            platform: 'netease',
            title: 'Fallback Title',
          ),
        );

        expect(result.info.name, 'Fallback Title');
      });

      test('应按优先级查找 cover 字段', () async {
        // cover > pic > imgurl > image > thumb
        final client = _createClient({
          'pic': 'https://img/pic.jpg',
          'thumb': 'https://img/thumb.jpg',
          'links': [],
        });

        final result = await client.fetchDetail(
          const VideoDetailRequest(id: '1', platform: 'qq', title: 'T'),
        );

        expect(result.info.cover, 'https://img/pic.jpg');
      });

      test('所有 cover 字段缺失时应返回空字符串', () async {
        final client = _createClient({'links': []});

        final result = await client.fetchDetail(
          const VideoDetailRequest(id: '1', platform: 'qq', title: 'T'),
        );

        expect(result.info.cover, '');
      });

      test('links 非 List 时应返回空列表', () async {
        final client = _createClient({'links': 'not a list'});

        final result = await client.fetchDetail(
          const VideoDetailRequest(id: '1', platform: 'qq', title: 'T'),
        );

        expect(result.links, isEmpty);
      });

      test('应过滤 quality=0 且 url 为空的 link', () async {
        final client = _createClient({
          'links': [
            {
              'quality': 1080,
              'url': 'https://cdn/a.mp4',
              'name': '',
              'format': '',
              'size': '',
            },
            {'quality': 0, 'url': '', 'name': '', 'format': '', 'size': ''},
            {
              'quality': 0,
              'url': 'https://cdn/b.mp4',
              'name': '',
              'format': '',
              'size': '',
            },
          ],
        });

        final result = await client.fetchDetail(
          const VideoDetailRequest(id: '1', platform: 'qq', title: 'T'),
        );

        expect(result.links, hasLength(2));
      });

      test('type 为非 int 时应尝试解析', () async {
        final client = _createClient({'type': '3', 'links': []});

        final result = await client.fetchDetail(
          const VideoDetailRequest(id: '1', platform: 'qq', title: 'T'),
        );

        expect(result.info.type, 3);
      });

      test('type 解析失败时应返回 0', () async {
        final client = _createClient({'type': 'abc', 'links': []});

        final result = await client.fetchDetail(
          const VideoDetailRequest(id: '1', platform: 'qq', title: 'T'),
        );

        expect(result.info.type, 0);
      });

      test('非 Map 响应应抛出 AppException', () async {
        final client = _createClient([1, 2, 3]);

        expect(
          () => client.fetchDetail(
            const VideoDetailRequest(id: '1', platform: 'qq', title: 'T'),
          ),
          throwsA(isA<AppException>()),
        );
      });
    });
  });
}

VideoDetailApiClient _createClient(dynamic payload) {
  final dio = Dio();
  dio.httpClientAdapter = _MockAdapter(payload);
  return VideoDetailApiClient(dio);
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
