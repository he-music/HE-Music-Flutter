import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/my/data/datasources/my_collection_api_client.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';

void main() {
  group('MyCollectionApiClient', () {
    group('fetchFavorites', () {
      test('playlists 类型应正确解析列表', () async {
        final client = _createClient({
          'list': [
            {
              'id': 'pl-1',
              'name': 'My Playlist',
              'cover': 'https://a.com/cover.jpg',
              'creator': 'test_user',
              'song_count': 10,
              'play_count': 100,
              'platform': 'qq',
              'description': 'desc',
            },
          ],
        });

        final result = await client.fetchFavorites(MyFavoriteType.playlists);
        expect(result, hasLength(1));
        expect(result.first.id, 'pl-1');
        expect(result.first.title, 'My Playlist');
        expect(result.first.type, MyFavoriteType.playlists);
        expect(result.first.coverUrl, 'https://a.com/cover.jpg');
        expect(result.first.songCount, '10');
      });

      test('albums 类型应正确解析列表', () async {
        final client = _createClient({
          'list': [
            {
              'id': 'alb-1',
              'name': 'Album One',
              'cover': 'https://a.com/alb.jpg',
              'artists': [
                {'id': 'ar-1', 'name': 'Artist A'},
              ],
              'song_count': 12,
              'publish_time': '2024-01-01',
              'description': '',
              'platform': 'qq',
              'language': '国语',
              'genre': 'pop',
              'type': 0,
              'is_finished': true,
              'play_count': 500,
            },
          ],
        });

        final result = await client.fetchFavorites(MyFavoriteType.albums);
        expect(result, hasLength(1));
        expect(result.first.id, 'alb-1');
        expect(result.first.title, 'Album One');
        expect(result.first.type, MyFavoriteType.albums);
      });

      test('artists 类型应正确解析列表', () async {
        final client = _createClient({
          'list': [
            {
              'id': 'ar-1',
              'name': '周杰伦',
              'cover': 'https://a.com/ar.jpg',
              'platform': 'qq',
              'description': '',
              'mv_count': 50,
              'song_count': 200,
              'album_count': 30,
              'alias': 'Jay Chou',
            },
          ],
        });

        final result = await client.fetchFavorites(MyFavoriteType.artists);
        expect(result, hasLength(1));
        expect(result.first.id, 'ar-1');
        expect(result.first.title, '周杰伦');
        expect(result.first.type, MyFavoriteType.artists);
      });

      test('list 不是 List 时返回空', () async {
        final client = _createClient({'list': 'not a list'});

        final result = await client.fetchFavorites(MyFavoriteType.playlists);
        expect(result, isEmpty);
      });
    });

    test('fetchCreatedPlaylists 应正确解析创建的歌单', () async {
      final client = _createClient({
        'list': [
          {
            'id': 'up-1',
            'name': 'Created Playlist',
            'cover': 'https://a.com/c.jpg',
            'creator': 'me',
            'song_count': 5,
            'play_count': 10,
            'platform': 'qq',
            'description': 'my list',
            'is_default': 1,
          },
        ],
      });

      final result = await client.fetchCreatedPlaylists();
      expect(result, hasLength(1));
      expect(result.first.id, 'up-1');
      expect(result.first.title, 'Created Playlist');
      expect(result.first.type, MyFavoriteType.playlists);
      expect(result.first.isDefault, isTrue);
    });

    test('fetchCreatedPlaylists 空 list 时返回空', () async {
      final client = _createClient({'list': []});
      final result = await client.fetchCreatedPlaylists();
      expect(result, isEmpty);
    });
  });
}

/// 根据请求路径返回不同响应的 mock 适配器。
MyCollectionApiClient _createClient(Map<String, dynamic> payload) {
  final dio = Dio();
  dio.httpClientAdapter = _PathBasedAdapter(payload);
  return MyCollectionApiClient(dio);
}

class _PathBasedAdapter implements HttpClientAdapter {
  _PathBasedAdapter(this._defaultPayload);

  final Map<String, dynamic> _defaultPayload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(_defaultPayload),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
