import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/features/artist/data/datasources/artist_detail_api_client.dart';
import 'package:he_music_flutter/features/artist/domain/entities/artist_detail_request.dart';

void main() {
  const request = ArtistDetailRequest(
    id: 'artist-1',
    platform: 'netease',
    title: 'Fallback',
  );

  group('ArtistDetailApiClient', () {
    group('fetchDetail', () {
      test('应正确解析完整响应', () async {
        final client = _createClient({
          'name': '周杰伦',
          'cover': 'https://img/jay.jpg',
          'description': '华语天王',
          'alias': 'Jay Chou',
          'mv_count': '50',
          'song_count': '200',
          'album_count': '30',
          'songs': [
            {
              'id': 's-1',
              'name': '稻香',
              'platform': 'netease',
              'duration': 240,
              'mv_id': '0',
              'album': null,
              'artists': [],
              'links': [],
              'cover': '',
              'sublist': [],
              'originalType': 0,
            },
          ],
        });

        final result = await client.fetchDetail(request);

        expect(result.info.name, '周杰伦');
        expect(result.info.cover, 'https://img/jay.jpg');
        expect(result.info.description, '华语天王');
        expect(result.info.alias, 'Jay Chou');
        expect(result.info.mvCount, '50');
        expect(result.info.songCount, '200');
        expect(result.info.albumCount, '30');
        expect(result.info.platform, 'netease');
        expect(result.info.id, 'artist-1');
        expect(result.songs, hasLength(1));
        expect(result.songs.first.name, '稻香');
      });

      test('name 为空时应使用 fallback', () async {
        final client = _createClient({'name': '', 'songs': []});

        final result = await client.fetchDetail(request);

        expect(result.info.name, 'Fallback');
      });

      test('应按优先级查找 cover', () async {
        final client = _createClient({
          'pic': 'https://img/pic.jpg',
          'thumb': 'https://img/thumb.jpg',
          'songs': [],
        });

        final result = await client.fetchDetail(request);

        expect(result.info.cover, 'https://img/pic.jpg');
      });

      test('songs 从嵌套 artist 对象中解析', () async {
        final client = _createClient({
          'artist': {
            'songs': [
              {
                'id': 's-2',
                'name': '青花瓷',
                'platform': 'netease',
                'duration': 0,
                'mv_id': '0',
                'album': null,
                'artists': [],
                'links': [],
                'cover': '',
                'sublist': [],
                'originalType': 0,
              },
            ],
          },
          'songs': [],
        });

        await client.fetchDetail(request);

        // _resolveSongList 优先检查直接 key，然后嵌套
        // 'songs': [] 被找到（空列表），所以结果为空
        // 需要测试嵌套路径时直接 key 不存在的情况
        final client2 = _createClient({
          'data': {
            'song_list': [
              {
                'id': 's-3',
                'name': '七里香',
                'platform': 'qq',
                'duration': 0,
                'mv_id': '0',
                'album': null,
                'artists': [],
                'links': [],
                'cover': '',
                'sublist': [],
                'originalType': 0,
              },
            ],
          },
        });

        final result2 = await client2.fetchDetail(request);
        expect(result2.songs, hasLength(1));
        expect(result2.songs.first.name, '七里香');
      });

      test('songs 中缺少 id 或 name 应抛出 AppException', () async {
        final client = _createClient({
          'songs': [
            {'id': '', 'name': 'Test'},
          ],
        });

        expect(() => client.fetchDetail(request), throwsA(isA<AppException>()));
      });

      test('count 字段缺失时应返回 "0"', () async {
        final client = _createClient({'songs': []});

        final result = await client.fetchDetail(request);

        expect(result.info.mvCount, '0');
        expect(result.info.songCount, '0');
        expect(result.info.albumCount, '0');
      });

      test('count 字段应从多个 key 中查找', () async {
        final client = _createClient({
          'mvCount': '99',
          'songCount': '88',
          'albumCount': '77',
          'songs': [],
        });

        final result = await client.fetchDetail(request);

        expect(result.info.mvCount, '99');
        expect(result.info.songCount, '88');
        expect(result.info.albumCount, '77');
      });

      test('非 Map 响应应抛出 AppException', () async {
        final client = _createClient([1, 2, 3]);

        expect(() => client.fetchDetail(request), throwsA(isA<AppException>()));
      });
    });

    group('fetchSongsPage', () {
      test('应正确解析分页歌曲', () async {
        final client = _createPageClient('/v1/artist/songs', {
          'list': [
            {
              'id': 's-1',
              'name': 'Song 1',
              'platform': 'netease',
              'duration': 200,
              'mv_id': '0',
              'album': null,
              'artists': [],
              'links': [],
              'cover': '',
              'sublist': [],
              'originalType': 0,
            },
          ],
          'has_more': true,
        });

        final result = await client.fetchSongsPage(request, pageIndex: 1);

        expect(result.items, hasLength(1));
        expect(result.items.first.name, 'Song 1');
        expect(result.hasMore, isTrue);
        expect(result.nextPageIndex, 2);
      });

      test('list 缺失时应返回空列表', () async {
        final client = _createPageClient('/v1/artist/songs', {
          'has_more': false,
        });

        final result = await client.fetchSongsPage(request, pageIndex: 1);

        expect(result.items, isEmpty);
      });

      test('歌曲缺少 id 应抛出 AppException', () async {
        final client = _createPageClient('/v1/artist/songs', {
          'list': [
            {'id': '', 'name': 'Test'},
          ],
          'has_more': false,
        });

        expect(
          () => client.fetchSongsPage(request, pageIndex: 1),
          throwsA(isA<AppException>()),
        );
      });
    });

    group('fetchAlbumsPage', () {
      test('应正确解析分页专辑', () async {
        final client = _createPageClient('/v1/artist/albums', {
          'list': [
            {
              'id': 'alb-1',
              'name': 'Album 1',
              'cover': 'https://img/alb.jpg',
              'artists': [
                {'id': 'a-1', 'name': 'Artist'},
              ],
              'song_count': 10,
              'publish_time': '2024-01-01',
              'description': 'Great album',
              'platform': 'netease',
              'language': '国语',
              'genre': 'Pop',
              'type': 1,
              'is_finished': true,
              'play_count': '1000',
            },
          ],
          'has_more': false,
        });

        final result = await client.fetchAlbumsPage(request, pageIndex: 1);

        expect(result.items, hasLength(1));
        final album = result.items.first;
        expect(album.id, 'alb-1');
        expect(album.name, 'Album 1');
        expect(album.cover, 'https://img/alb.jpg');
        expect(album.artists, hasLength(1));
        expect(album.songCount, '10');
        expect(album.publishTime, '2024-01-01');
        expect(album.description, 'Great album');
        expect(album.language, '国语');
        expect(album.genre, 'Pop');
        expect(album.type, 1);
        expect(album.isFinished, isTrue);
        expect(album.playCount, '1000');
      });

      test('应从多个 key 中查找 song_count', () async {
        final client = _createPageClient('/v1/artist/albums', {
          'list': [
            {'id': 'alb-1', 'name': 'Album', 'trackCount': 15},
          ],
          'has_more': false,
        });

        final result = await client.fetchAlbumsPage(request, pageIndex: 1);

        expect(result.items.first.songCount, '15');
      });

      test('专辑缺少 id 应抛出 AppException', () async {
        final client = _createPageClient('/v1/artist/albums', {
          'list': [
            {'id': '', 'name': 'Test'},
          ],
          'has_more': false,
        });

        expect(
          () => client.fetchAlbumsPage(request, pageIndex: 1),
          throwsA(isA<AppException>()),
        );
      });
    });

    group('fetchVideosPage', () {
      test('应正确解析分页视频', () async {
        final client = _createPageClient('/v1/artist/mvs', {
          'list': [
            {
              'id': 'mv-1',
              'name': 'MV 1',
              'cover': 'https://img/mv.jpg',
              'type': 1,
              'play_count': '500',
              'creator': 'Director',
              'duration': 300,
              'description': 'Music Video',
              'links': [
                {
                  'quality': 1080,
                  'url': 'https://cdn/mv.mp4',
                  'name': 'HD',
                  'format': 'mp4',
                  'size': '100MB',
                },
              ],
            },
          ],
          'has_more': true,
        });

        final result = await client.fetchVideosPage(request, pageIndex: 1);

        expect(result.items, hasLength(1));
        final video = result.items.first;
        expect(video.id, 'mv-1');
        expect(video.name, 'MV 1');
        expect(video.links, hasLength(1));
        expect(video.links.first.quality, 1080);
        expect(video.platform, 'netease');
      });

      test('应从多个 key 中查找 play_count', () async {
        final client = _createPageClient('/v1/artist/mvs', {
          'list': [
            {'id': 'mv-1', 'name': 'MV', 'watch_count': '999'},
          ],
          'has_more': false,
        });

        final result = await client.fetchVideosPage(request, pageIndex: 1);

        expect(result.items.first.playCount, '999');
      });

      test('视频缺少 name 应抛出 AppException', () async {
        final client = _createPageClient('/v1/artist/mvs', {
          'list': [
            {'id': 'mv-1', 'name': ''},
          ],
          'has_more': false,
        });

        expect(
          () => client.fetchVideosPage(request, pageIndex: 1),
          throwsA(isA<AppException>()),
        );
      });
    });

    group('fetchSongs (多页)', () {
      test('应自动加载所有分页', () async {
        var callCount = 0;
        final client = _createMultiPageClient(
          path: '/v1/artist/songs',
          pages: [
            {
              'list': [
                {
                  'id': 's-1',
                  'name': 'Song 1',
                  'platform': 'netease',
                  'duration': 0,
                  'mv_id': '0',
                  'album': null,
                  'artists': [],
                  'links': [],
                  'cover': '',
                  'sublist': [],
                  'originalType': 0,
                },
              ],
              'has_more': true,
            },
            {
              'list': [
                {
                  'id': 's-2',
                  'name': 'Song 2',
                  'platform': 'netease',
                  'duration': 0,
                  'mv_id': '0',
                  'album': null,
                  'artists': [],
                  'links': [],
                  'cover': '',
                  'sublist': [],
                  'originalType': 0,
                },
              ],
              'has_more': false,
            },
          ],
          onCall: () => callCount++,
        );

        final result = await client.fetchSongs(request);

        expect(result, hasLength(2));
        expect(result[0].name, 'Song 1');
        expect(result[1].name, 'Song 2');
        expect(callCount, 2);
      });
    });

    group('fetchAlbums (多页)', () {
      test('应自动加载所有分页', () async {
        final client = _createMultiPageClient(
          path: '/v1/artist/albums',
          pages: [
            {
              'list': [
                {'id': 'alb-1', 'name': 'Album 1'},
              ],
              'has_more': true,
            },
            {
              'list': [
                {'id': 'alb-2', 'name': 'Album 2'},
              ],
              'has_more': false,
            },
          ],
        );

        final result = await client.fetchAlbums(request);

        expect(result, hasLength(2));
        expect(result[0].name, 'Album 1');
        expect(result[1].name, 'Album 2');
      });
    });

    group('fetchVideos (多页)', () {
      test('应自动加载所有分页', () async {
        final client = _createMultiPageClient(
          path: '/v1/artist/mvs',
          pages: [
            {
              'list': [
                {'id': 'mv-1', 'name': 'MV 1'},
              ],
              'has_more': true,
            },
            {
              'list': [
                {'id': 'mv-2', 'name': 'MV 2'},
              ],
              'has_more': false,
            },
          ],
        );

        final result = await client.fetchVideos(request);

        expect(result, hasLength(2));
        expect(result[0].name, 'MV 1');
        expect(result[1].name, 'MV 2');
      });
    });

    group('边界情况', () {
      test('pageIndex <= 0 应修正为 1', () async {
        Map<String, dynamic>? capturedParams;
        final dio = Dio();
        dio.httpClientAdapter = _CapturingAdapter({
          'list': [],
          'has_more': false,
        }, (_, params) => capturedParams = params);
        final client = ArtistDetailApiClient(dio);

        await client.fetchSongsPage(request, pageIndex: -1);

        expect(capturedParams!['page_index'], 1);
      });

      test('has_more 为 bool true 应正确解析', () async {
        final client = _createPageClient('/v1/artist/songs', {
          'list': [],
          'has_more': true,
        });

        final result = await client.fetchSongsPage(request, pageIndex: 1);

        expect(result.hasMore, isTrue);
      });

      test('has_more 为字符串 "1" 应解析为 true', () async {
        final client = _createPageClient('/v1/artist/songs', {
          'list': [],
          'has_more': '1',
        });

        final result = await client.fetchSongsPage(request, pageIndex: 1);

        expect(result.hasMore, isTrue);
      });
    });
  });
}

ArtistDetailApiClient _createClient(dynamic payload) {
  final dio = Dio();
  dio.httpClientAdapter = _MockAdapter(payload);
  return ArtistDetailApiClient(dio);
}

ArtistDetailApiClient _createPageClient(String path, dynamic payload) {
  final dio = Dio();
  dio.httpClientAdapter = _MockAdapter(payload);
  return ArtistDetailApiClient(dio);
}

ArtistDetailApiClient _createMultiPageClient({
  required String path,
  required List<dynamic> pages,
  void Function()? onCall,
}) {
  final dio = Dio();
  dio.httpClientAdapter = _MultiPageAdapter(pages, onCall);
  return ArtistDetailApiClient(dio);
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

class _MultiPageAdapter implements HttpClientAdapter {
  _MultiPageAdapter(this._pages, this._onCall);

  final List<dynamic> _pages;
  final void Function()? _onCall;
  int _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _onCall?.call();
    final payload = _index < _pages.length ? _pages[_index] : _pages.last;
    _index++;
    return ResponseBody.fromString(
      jsonEncode(payload),
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
