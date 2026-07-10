import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';

void main() {
  group('OnlineApiClient', () {
    group('fetchHotKeywords', () {
      test('应正确解析 keys 列表', () async {
        final client = _createClient({
          'keys': ['周杰伦', '林俊杰'],
        });

        final result = await client.fetchHotKeywords(platform: 'qq');

        expect(result, hasLength(2));
        expect(result.first, '周杰伦');
      });

      test('keys 为空时应返回默认热词', () async {
        final client = _createClient({'keys': []});

        final result = await client.fetchHotKeywords();

        expect(result, isNotEmpty);
        expect(result.first, '周杰伦');
      });

      test('无 keys 字段时应返回默认热词', () async {
        final client = _createClient(<String, dynamic>{});

        final result = await client.fetchHotKeywords();

        expect(result, isNotEmpty);
        expect(result, contains('Taylor Swift'));
      });
    });

    group('fetchSearchSuggestions', () {
      test('应正确解析建议列表', () async {
        final client = _createClient({
          'keys': ['suggestion1', 'suggestion2'],
        });

        final result = await client.fetchSearchSuggestions(
          keyword: 'test',
          platform: 'qq',
        );

        expect(result, hasLength(2));
        expect(result.first, 'suggestion1');
      });

      test('空关键字应返回空列表', () async {
        final client = _createClient({
          'keys': ['a'],
        });

        final result = await client.fetchSearchSuggestions(keyword: '  ');

        expect(result, isEmpty);
      });

      test('无 keys 时返回空列表', () async {
        final client = _createClient(<String, dynamic>{});

        final result = await client.fetchSearchSuggestions(keyword: 'test');

        expect(result, isEmpty);
      });
    });

    group('searchMusic', () {
      test('应正确解析搜索结果列表', () async {
        final client = _createClient({
          'list': [
            {'id': 's1', 'name': 'Song 1', 'platform': 'qq'},
            {'id': 's2', 'name': 'Song 2', 'platform': 'qq'},
          ],
        });

        final result = await client.searchMusic(
          keyword: 'test',
          platform: 'qq',
        );

        expect(result, hasLength(2));
        expect(result.first['id'], 's1');
      });

      test('空 list 时返回空', () async {
        final client = _createClient({'list': []});

        final result = await client.searchMusic(
          keyword: 'test',
          platform: 'qq',
        );

        expect(result, isEmpty);
      });
    });

    group('comprehensiveSearch', () {
      test('应正确解析综合搜索结果', () async {
        final client = _createClient({
          'key': '周杰伦',
          'bestMatch': {
            'primary': {
              'resourceType': 'artist',
              'artist': {'id': 'ar-1', 'name': '周杰伦'},
            },
          },
          'song': {
            'list': [
              {'id': 's1', 'name': '晴天'},
            ],
            'total_count': 100,
          },
          'playlist': {
            'list': [
              {'id': 'p1', 'name': '周杰伦精选'},
            ],
            'total_count': 50,
          },
          'album': {'list': [], 'total_count': 0},
          'mv': {'list': [], 'total_count': 0},
          'artist': {'list': [], 'total_count': 0},
        });

        final result = await client.comprehensiveSearch(
          keyword: '周杰伦',
          platform: 'qq',
        );

        expect(result.keyword, '周杰伦');
        expect(result.hasBestMatch, isTrue);
        expect(result.bestMatch.first.resourceType, 'artist');
        expect(result.bestMatch.first.data['name'], '周杰伦');
        expect(result.song.items, hasLength(1));
        expect(result.song.totalCount, 100);
        expect(result.playlist.items, hasLength(1));
      });

      test('无 bestMatch 时应返回空列表', () async {
        final client = _createClient({
          'key': 'test',
          'song': {'list': [], 'total_count': 0},
          'playlist': {'list': [], 'total_count': 0},
          'album': {'list': [], 'total_count': 0},
          'mv': {'list': [], 'total_count': 0},
          'artist': {'list': [], 'total_count': 0},
        });

        final result = await client.comprehensiveSearch(
          keyword: 'test',
          platform: 'qq',
        );

        expect(result.hasBestMatch, isFalse);
        expect(result.bestMatch, isEmpty);
      });
    });

    group('fetchSongUrl', () {
      test('应正确解析歌曲 URL 响应', () async {
        final client = _createClient({
          'url': 'https://a.com/song.mp3',
          'quality': 320,
        });

        final result = await client.fetchSongUrl(songId: 's1', platform: 'qq');

        expect(result['url'], 'https://a.com/song.mp3');
        expect(result['quality'], 320);
      });
    });

    group('fetchSongLyric', () {
      test('应正确解析歌词响应', () async {
        final client = _createClient({
          'lyric': '[00:00.00]Hello World',
          'tlyric': '[00:00.00]你好世界',
        });

        final result = await client.fetchSongLyric(
          songId: 's1',
          platform: 'qq',
        );

        expect(result['lyric'], '[00:00.00]Hello World');
        expect(result['tlyric'], '[00:00.00]你好世界');
      });
    });

    group('toggleSongFavorite', () {
      test('like=true 时应发送 POST 请求', () async {
        String? capturedMethod;
        final client = _createClient({
          'success': true,
        }, captureMethod: (m) => capturedMethod = m);

        await client.toggleSongFavorite(
          songId: 's1',
          platform: 'qq',
          like: true,
        );

        expect(capturedMethod, 'POST');
      });

      test('like=false 时应发送 DELETE 请求', () async {
        String? capturedMethod;
        final client = _createClient({
          'success': true,
        }, captureMethod: (m) => capturedMethod = m);

        await client.toggleSongFavorite(
          songId: 's1',
          platform: 'qq',
          like: false,
        );

        expect(capturedMethod, 'DELETE');
      });
    });

    group('fetchProfile', () {
      test('应返回用户信息 Map', () async {
        final client = _createClient({
          'id': 'u-1',
          'username': 'test',
          'nickname': 'Test User',
        });

        final result = await client.fetchProfile();

        expect(result['id'], 'u-1');
        expect(result['username'], 'test');
      });
    });

    group('logout', () {
      test('应使用 JSON Content-Type', () async {
        RequestOptions? capturedRequest;
        final client = _createClient(
          <String, dynamic>{},
          captureRequest: (options) => capturedRequest = options,
        );

        await client.logout();

        expect(capturedRequest?.contentType, Headers.jsonContentType);
      });
    });

    group('fetchPlatforms', () {
      test('应正确解析平台列表', () async {
        final client = _createClient({
          'list': [
            {'id': 'qq', 'name': 'QQ Music'},
            {'id': 'kg', 'name': 'Kugou'},
          ],
        });

        final result = await client.fetchPlatforms();

        expect(result, hasLength(2));
        expect(result.first['id'], 'qq');
      });
    });
  });
}

OnlineApiClient _createClient(
  dynamic payload, {
  void Function(String method)? captureMethod,
  void Function(RequestOptions options)? captureRequest,
}) {
  final dio = Dio();
  dio.httpClientAdapter = _MockAdapter(
    payload,
    captureMethod: captureMethod,
    captureRequest: captureRequest,
  );
  return OnlineApiClient(dio);
}

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._payload, {this.captureMethod, this.captureRequest});

  final dynamic _payload;
  final void Function(String method)? captureMethod;
  final void Function(RequestOptions options)? captureRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captureMethod?.call(options.method);
    captureRequest?.call(options);
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
