import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

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
      test('应正确解析普通资源及分页信息', () async {
        final client = _createClient({
          'platform': 'qq',
          'key': 'test',
          'list': [
            {'id': 'p1', 'name': 'Playlist 1', 'platform': 'qq'},
            {'id': 'p2', 'name': 'Playlist 2', 'platform': 'qq'},
          ],
          'page_index': 2,
          'page_size': 20,
          'total_count': 41,
          'has_more': true,
        });

        final result = await client.searchMusic(
          keyword: 'test',
          platform: 'qq',
          type: 'playlist',
          pageIndex: 2,
          pageSize: 20,
        );

        expect(result.items, hasLength(2));
        expect(result.items.first['id'], 'p1');
        expect(result.pageIndex, 2);
        expect(result.pageSize, 20);
        expect(result.totalCount, 41);
        expect(result.hasMore, isTrue);
      });

      test('空 list 时返回空', () async {
        final client = _createClient({'list': []});

        final result = await client.searchMusic(
          keyword: 'test',
          platform: 'qq',
          type: 'playlist',
        );

        expect(result.items, isEmpty);
      });

      test('拒绝通过通用入口读取歌曲包装数据', () async {
        final client = _createClient({'list': []});

        expect(
          () =>
              client.searchMusic(keyword: 'test', platform: 'qq', type: 'song'),
          throwsArgumentError,
        );
      });
    });

    group('searchSongs', () {
      test('应将歌曲结果解析为 SearchSongInfo', () async {
        final client = _createClient({
          'platform': 'qq',
          'key': '晴天',
          'list': [
            {
              'song': {'id': 's1', 'name': '晴天'},
              'sublist': <dynamic>[],
              'original_type': 1,
              'lyric_snippet': '故事的小黄花',
              'lyric': '',
              'matched_keywords': ['晴天'],
            },
          ],
          'page_index': 1,
          'page_size': 30,
          'total_count': 1,
          'has_more': false,
        });

        final result = await client.searchSongs(keyword: '晴天', platform: 'qq');

        expect(result.items.single.song.id, 's1');
        expect(result.items.single.song.platform, 'qq');
        expect(result.items.single.originalType, 1);
        expect(result.items.single.lyricSnippet, '故事的小黄花');
        expect(result.hasMore, isFalse);
      });
    });

    group('searchLyrics', () {
      test('应请求固定歌词路径并解析完整歌词', () async {
        RequestOptions? captured;
        final client = _createClient({
          'platform': 'netease',
          'key': '故事',
          'list': [
            {
              'song': {'id': 's1', 'name': '晴天'},
              'sublist': <dynamic>[],
              'original_type': 0,
              'lyric_snippet': '从前从前有个人爱你很久',
              'lyric': '故事的小黄花\n从出生那年就飘着',
              'matched_keywords': ['故事'],
            },
          ],
          'page_index': 1,
          'page_size': 30,
          'total_count': 31,
          'has_more': true,
        }, captureRequest: (options) => captured = options);

        final result = await client.searchLyrics(
          keyword: '故事',
          platform: 'netease',
        );

        expect(captured?.path, '/v1/lyric/search');
        expect(captured?.queryParameters['key'], '故事');
        expect(captured?.queryParameters['platform'], 'netease');
        expect(captured?.queryParameters['page_index'], 1);
        expect(captured?.queryParameters['page_size'], 30);
        expect(result.items.single.lyric, contains('从出生那年'));
        expect(result.hasMore, isTrue);
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
            'recommendations': [
              {
                'resource_type': 'song',
                'song': {
                  'song': {'id': 's2', 'name': '七里香'},
                  'sublist': <dynamic>[],
                  'original_type': 1,
                  'lyric_snippet': '窗外的麻雀',
                  'lyric': '',
                  'matched_keywords': ['周杰伦'],
                },
              },
            ],
          },
          'song': {
            'list': [
              {
                'song': {'id': 's1', 'name': '晴天'},
                'sublist': <dynamic>[],
                'original_type': 1,
                'lyric_snippet': '故事的小黄花',
                'lyric': '',
                'matched_keywords': ['周杰伦'],
              },
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
        expect(
          (result.bestMatch.first.data as Map<String, dynamic>)['name'],
          '周杰伦',
        );
        expect(result.bestMatch[1].data, isA<SearchSongInfo>());
        expect((result.bestMatch[1].data as SearchSongInfo).song.id, 's2');
        expect(result.song.items, hasLength(1));
        expect(result.song.items.single.song.id, 's1');
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

    test('后台自动请求可标记为静默错误', () async {
      final requests = <RequestOptions>[];
      final client = _createClient(<String, dynamic>{
        'list': <dynamic>[],
      }, captureRequest: requests.add);

      await client.fetchDefaultKeywords(silentErrorMessage: true);
      await client.getAuthStatus(
        state: 'oauth-state',
        silentErrorMessage: true,
      );
      await client.getQrLoginSessionStatus(
        sessionId: 'qr-session',
        silentErrorMessage: true,
      );

      expect(requests, hasLength(3));
      expect(
        requests.every(
          (request) => request.extra['silentErrorMessage'] == true,
        ),
        isTrue,
      );
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
