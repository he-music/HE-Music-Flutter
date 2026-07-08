import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/features/artist/data/datasources/artist_plaza_api_client.dart';

void main() {
  group('ArtistPlazaApiClient', () {
    group('fetchFilters', () {
      test('应正确解析 filters 列表', () async {
        final client = _createClient({
          'filters': [
            {
              'id': 'gender',
              'options': [
                {'value': 'male', 'label': '男'},
              ],
            },
          ],
        });

        final result = await client.fetchFilters(platform: 'netease');

        expect(result, hasLength(1));
        expect(result.first.id, 'gender');
        expect(result.first.platform, 'netease');
      });

      test('filters 非 List 时应抛出 AppException', () async {
        final client = _createClient({'filters': 123});

        expect(
          () => client.fetchFilters(platform: 'qq'),
          throwsA(isA<AppException>()),
        );
      });

      test('非 Map 响应应抛出 AppException', () async {
        final client = _createClient('string response');

        expect(
          () => client.fetchFilters(platform: 'qq'),
          throwsA(isA<AppException>()),
        );
      });
    });

    group('fetchArtists', () {
      test('应正确解析歌手列表', () async {
        final client = _createClient({
          'list': [
            {
              'id': 'artist-1',
              'name': '周杰伦',
              'cover': 'https://img/jay.jpg',
              'platform': 'netease',
              'description': '',
              'mv_count': '50',
              'song_count': '200',
              'album_count': '30',
              'alias': 'Jay Chou',
            },
          ],
          'has_more': true,
        });

        final result = await client.fetchArtists(
          platform: 'netease',
          filters: {'gender': 'male'},
        );

        expect(result.list, hasLength(1));
        expect(result.list.first.id, 'artist-1');
        expect(result.list.first.name, '周杰伦');
        expect(result.list.first.platform, 'netease');
        expect(result.hasMore, isTrue);
      });

      test('pageIndex <= 0 应修正为 1', () async {
        Map<String, dynamic>? capturedParams;
        final client = _createClientWithCapture(
          payload: {'list': [], 'has_more': false},
          onFetch: (_, params) => capturedParams = params,
        );

        await client.fetchArtists(platform: 'qq', filters: {}, pageIndex: 0);

        expect(capturedParams!['page_index'], 1);
      });

      test('pageSize <= 0 应修正为 50', () async {
        Map<String, dynamic>? capturedParams;
        final client = _createClientWithCapture(
          payload: {'list': [], 'has_more': false},
          onFetch: (_, params) => capturedParams = params,
        );

        await client.fetchArtists(platform: 'qq', filters: {}, pageSize: -10);

        expect(capturedParams!['page_size'], 50);
      });

      test('list 非 List 时应抛出 AppException', () async {
        final client = _createClient({'list': 'bad', 'has_more': false});

        expect(
          () => client.fetchArtists(platform: 'qq', filters: {}),
          throwsA(isA<AppException>()),
        );
      });

      test('has_more 为 num 0 时应解析为 false', () async {
        final client = _createClient({
          'list': [
            {
              'id': '1',
              'name': 'A',
              'cover': '',
              'platform': 'qq',
              'description': '',
              'mv_count': '0',
              'song_count': '0',
              'album_count': '0',
              'alias': '',
            },
          ],
          'has_more': 0,
        });

        final result = await client.fetchArtists(platform: 'qq', filters: {});

        expect(result.hasMore, isFalse);
      });

      test('has_more 缺失时应根据列表长度推断', () async {
        final client = _createClient({
          'list': List.generate(
            2,
            (i) => {
              'id': '$i',
              'name': 'A$i',
              'cover': '',
              'platform': 'qq',
              'description': '',
              'mv_count': '0',
              'song_count': '0',
              'album_count': '0',
              'alias': '',
            },
          ),
        });

        final result = await client.fetchArtists(
          platform: 'qq',
          filters: {},
          pageSize: 2,
        );

        expect(result.hasMore, isTrue);
      });

      test('非 Map 响应应抛出 AppException', () async {
        final client = _createClient([1, 2]);

        expect(
          () => client.fetchArtists(platform: 'qq', filters: {}),
          throwsA(isA<AppException>()),
        );
      });
    });
  });
}

ArtistPlazaApiClient _createClient(dynamic payload) {
  final dio = Dio();
  dio.httpClientAdapter = _MockAdapter(payload);
  return ArtistPlazaApiClient(dio);
}

ArtistPlazaApiClient _createClientWithCapture({
  required dynamic payload,
  required void Function(String path, Map<String, dynamic> params) onFetch,
}) {
  final dio = Dio();
  dio.httpClientAdapter = _CapturingAdapter(payload, onFetch);
  return ArtistPlazaApiClient(dio);
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
