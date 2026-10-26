import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/features/my/data/datasources/user_playlist_detail_api_client.dart';
import 'package:he_music_flutter/features/my/domain/entities/user_playlist_detail_request.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_songs_page_result.dart';

void main() {
  group('UserPlaylistDetailApiClient', () {
    test('fetchInfo 和 fetchSongs 应分别解析歌单详情和歌曲列表', () async {
      final client = _createMultiClient({
        '/v1/user/playlist': {
          'name': 'Test Playlist',
          'cover': 'https://a.com/cover.jpg',
          'creator': 'test_user',
          'song_count': '2',
          'play_count': '500',
          'description': 'A test playlist',
        },
        '/v1/user/playlist/songs': {
          'list': [
            {
              'id': 's1',
              'name': 'Song One',
              'artist': 'Artist A',
              'cover': '',
              'platform': 'qq',
            },
            {
              'id': 's2',
              'name': 'Song Two',
              'artist': 'Artist B',
              'cover': '',
              'platform': 'qq',
            },
          ],
        },
      });

      const request = UserPlaylistDetailRequest(
        id: 'pl-1',
        title: 'Fallback Title',
      );
      final info = await client.fetchInfo(request);
      final result = await client.fetchSongs(request);

      expect(info.name, 'Test Playlist');
      expect(info.cover, 'https://a.com/cover.jpg');
      expect(info.creator, 'test_user');
      expect(info.songCount, '2');
      expect(info.playCount, '500');
      expect(info.description, 'A test playlist');
      expect(info.isDefault, isFalse);
      expect(result.songs, hasLength(2));
      expect(result.songs.first.id, 's1');
      expect(result.pageIndex, 1);
      expect(result.pageSize, playlistDetailSongsPageSize);
      expect(result.totalCount, 2);
      expect(result.hasMore, isFalse);
    });

    test('fetchSongs 传递后续页参数并保留服务端分页元数据', () async {
      final requests = <Map<String, dynamic>>[];
      final client = _createMultiClient(
        {
          'list': [
            {'id': 's1001', 'name': 'Next page', 'platform': 'qq'},
          ],
          'page_index': '2',
          'page_size': '1000',
          'total_count': '2500',
          'has_more': 1,
        },
        onGet: (options) {
          expect(options.path, '/v1/user/playlist/songs');
          requests.add(Map.of(options.queryParameters));
        },
      );
      const request = UserPlaylistDetailRequest(id: 'pl-1', title: 'T');
      await client.fetchSongs(request);
      final result = await client.fetchSongs(request, pageIndex: 2);
      expect(requests, [
        {
          'id': 'pl-1',
          'page_index': 1,
          'page_size': playlistDetailSongsPageSize,
        },
        {
          'id': 'pl-1',
          'page_index': 2,
          'page_size': playlistDetailSongsPageSize,
        },
      ]);
      expect(result.songs.single.id, 's1001');
      expect(result.pageIndex, 2);
      expect(result.pageSize, 1000);
      expect(result.totalCount, 2500);
      expect(result.hasMore, isTrue);
    });

    test('fetchSongs 支持自定义分页大小且缺失元数据时回退到请求参数', () async {
      final client = _createMultiClient(
        {'list': []},
        onGet: (options) {
          expect(options.queryParameters['page_index'], 3);
          expect(options.queryParameters['page_size'], 25);
        },
      );
      final result = await client.fetchSongs(
        const UserPlaylistDetailRequest(id: 'pl-1', title: 'T'),
        pageIndex: 3,
        pageSize: 25,
      );
      expect(result.pageIndex, 3);
      expect(result.pageSize, 25);
      expect(result.totalCount, 0);
      expect(result.hasMore, isFalse);
    });

    for (final pageSize in [0, -1, playlistDetailSongsPageSize + 1]) {
      test('fetchSongs 规范化无效请求和响应分页字段 pageSize=$pageSize', () async {
        final client = _createMultiClient(
          {
            'page_index': 0,
            'page_size': -1,
            'total_count': -1,
            'has_more': 'true',
          },
          onGet: (options) {
            expect(options.queryParameters['page_index'], 1);
            expect(
              options.queryParameters['page_size'],
              playlistDetailSongsPageSize,
            );
          },
        );
        final result = await client.fetchSongs(
          const UserPlaylistDetailRequest(id: 'pl-1', title: 'T'),
          pageIndex: 0,
          pageSize: pageSize,
        );
        expect(result.songs, isEmpty);
        expect(result.pageIndex, 1);
        expect(result.pageSize, playlistDetailSongsPageSize);
        expect(result.totalCount, 0);
        expect(result.hasMore, isTrue);
      });
    }

    test('fetchDetail 应透传默认歌单标记', () async {
      final client = _createMultiClient({
        '/v1/user/playlist': {'is_default': 1},
        '/v1/user/playlist/songs': {'list': []},
      });
      final result = await client.fetchInfo(
        const UserPlaylistDetailRequest(id: 'pl-1', title: 'T'),
      );
      expect(result.isDefault, isTrue);
    });

    test('fetchDetail 在 name 缺失时回退到 request.title', () async {
      final client = _createMultiClient({
        '/v1/user/playlist': <String, dynamic>{},
        '/v1/user/playlist/songs': {'list': []},
      });
      final result = await client.fetchInfo(
        const UserPlaylistDetailRequest(id: 'pl-1', title: 'Fallback Title'),
      );
      expect(result.name, 'Fallback Title');
    });

    test('fetchDetail 的 cover 应尝试多个 key', () async {
      final client = _createMultiClient({
        '/v1/user/playlist': {'pic': 'https://a.com/pic.jpg'},
        '/v1/user/playlist/songs': {'list': []},
      });
      final result = await client.fetchInfo(
        const UserPlaylistDetailRequest(id: 'pl-1', title: 'T'),
      );
      expect(result.cover, 'https://a.com/pic.jpg');
    });

    test('fetchDetail 的 song_count 应尝试多个 key', () async {
      final client = _createMultiClient({
        '/v1/user/playlist': {'trackCount': 42},
        '/v1/user/playlist/songs': {'list': []},
      });
      final result = await client.fetchInfo(
        const UserPlaylistDetailRequest(id: 'pl-1', title: 'T'),
      );
      expect(result.songCount, '42');
    });

    test('fetchInfo 在 song_count 缺失时保留空值供页面使用歌曲数回退', () async {
      final client = _createMultiClient({
        '/v1/user/playlist': <String, dynamic>{},
        '/v1/user/playlist/songs': {
          'list': [
            {'id': 's1', 'name': 'A', 'platform': 'qq'},
            {'id': 's2', 'name': 'B', 'platform': 'qq'},
          ],
        },
      });
      final result = await client.fetchInfo(
        const UserPlaylistDetailRequest(id: 'pl-1', title: 'T'),
      );
      expect(result.songCount, isEmpty);
    });

    test('fetchDetail 在歌曲缺少 id 或 name 时应抛出 AppException', () async {
      final client = _createMultiClient({
        '/v1/user/playlist': <String, dynamic>{},
        '/v1/user/playlist/songs': {
          'list': [
            {'id': '', 'name': 'Song', 'platform': 'qq'},
          ],
        },
      });
      expect(
        () => client.fetchSongs(
          const UserPlaylistDetailRequest(id: 'pl-1', title: 'T'),
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('updatePlaylist 应发送 PUT 请求', () async {
      var putCalled = false;
      final client = _createMultiClient(
        <String, dynamic>{},
        onPut: (options) {
          putCalled = true;
          expect(options.path, '/v1/user/playlist');
        },
      );
      await client.updatePlaylist(
        id: 'pl-1',
        name: 'New Name',
        cover: 'https://a.com/new.jpg',
        description: 'New desc',
      );
      expect(putCalled, isTrue);
    });

    test('deletePlaylist 应发送 DELETE 请求', () async {
      var deleteCalled = false;
      final client = _createMultiClient(
        <String, dynamic>{},
        onDelete: (options) {
          deleteCalled = true;
          expect(options.path, '/v1/user/playlist');
        },
      );
      await client.deletePlaylist('pl-1');
      expect(deleteCalled, isTrue);
    });
  });
}

/// 创建根据路径分发响应的 UserPlaylistDetailApiClient。
UserPlaylistDetailApiClient _createMultiClient(
  dynamic payload, {
  void Function(RequestOptions)? onGet,
  void Function(RequestOptions)? onPut,
  void Function(RequestOptions)? onDelete,
}) {
  final dio = Dio();
  dio.httpClientAdapter = _PathAdapter(
    payload,
    onGet: onGet,
    onPut: onPut,
    onDelete: onDelete,
  );
  return UserPlaylistDetailApiClient(dio);
}

class _PathAdapter implements HttpClientAdapter {
  _PathAdapter(this._payload, {this.onGet, this.onPut, this.onDelete});

  final dynamic _payload;
  final void Function(RequestOptions)? onGet;
  final void Function(RequestOptions)? onPut;
  final void Function(RequestOptions)? onDelete;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // 拦截 PUT 和 DELETE 调用
    if (options.method == 'PUT') {
      onPut?.call(options);
      return ResponseBody.fromString('', 200);
    }
    if (options.method == 'DELETE') {
      onDelete?.call(options);
      return ResponseBody.fromString('', 200);
    }
    onGet?.call(options);

    // GET 请求：根据路径返回对应 payload
    dynamic body;
    if (_payload is Map<String, dynamic> &&
        _payload.containsKey(options.path)) {
      body = _payload[options.path];
    } else {
      body = _payload;
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
