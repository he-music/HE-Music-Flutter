import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/features/playlist/data/datasources/playlist_detail_api_client.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_request.dart';

void main() {
  group('PlaylistDetailApiClient', () {
    const request = PlaylistDetailRequest(
      id: 'playlist-1',
      platform: 'qq',
      title: 'Fallback',
    );

    test(
      'fetchInfo parses playlist metadata without requesting songs',
      () async {
        final adapter = _PathAdapter(<String, dynamic>{
          '/v1/playlist': <String, dynamic>{
            'name': '测试歌单',
            'cover': 'https://example.com/cover.jpg',
            'creator': '创建者',
            'song_count': '2',
            'play_count': '10',
            'description': '描述',
          },
        });
        final client = _createClient(adapter);

        final info = await client.fetchInfo(request);

        expect(adapter.requestedPaths, <String>['/v1/playlist']);
        expect(info.name, '测试歌单');
        expect(info.songCount, '2');
        expect(info.songs, isEmpty);
      },
    );

    test(
      'fetchSongs parses pagination and sends the requested cursor',
      () async {
        final adapter = _PathAdapter(<String, dynamic>{
          '/v1/playlist/songs': <String, dynamic>{
            'list': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'song-1', 'name': '歌曲', 'platform': 'qq'},
            ],
            'page_index': 2,
            'page_size': 300,
            'total_count': 450,
            'has_more': true,
          },
        });
        final client = _createClient(adapter);

        final result = await client.fetchSongs(
          request,
          pageIndex: 2,
          pageSize: 300,
        );

        expect(adapter.requestedPaths, <String>['/v1/playlist/songs']);
        expect(adapter.requestedQueries.single, <String, dynamic>{
          'id': 'playlist-1',
          'platform': 'qq',
          'page_index': 2,
          'page_size': 300,
        });
        expect(result.songs.single.id, 'song-1');
        expect(result.pageIndex, 2);
        expect(result.pageSize, 300);
        expect(result.totalCount, 450);
        expect(result.hasMore, true);
      },
    );

    test('fetchSongs falls back when response pagination is invalid', () async {
      final client = _createClient(
        _PathAdapter(<String, dynamic>{
          '/v1/playlist/songs': <String, dynamic>{
            'list': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'song-1', 'name': '歌曲'},
            ],
            'page_index': 0,
            'page_size': -1,
            'total_count': -1,
            'has_more': 1,
          },
        }),
      );

      final result = await client.fetchSongs(
        request,
        pageIndex: 3,
        pageSize: 300,
      );

      expect(result.pageIndex, 3);
      expect(result.pageSize, 300);
      expect(result.totalCount, 1);
      expect(result.hasMore, true);
    });

    test('fetchSongs rejects an item without identity', () async {
      final client = _createClient(
        _PathAdapter(<String, dynamic>{
          '/v1/playlist/songs': <String, dynamic>{
            'list': <Map<String, dynamic>>[
              <String, dynamic>{'id': '', 'name': '歌曲'},
            ],
          },
        }),
      );

      expect(() => client.fetchSongs(request), throwsA(isA<AppException>()));
    });
  });
}

PlaylistDetailApiClient _createClient(_PathAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return PlaylistDetailApiClient(dio);
}

class _PathAdapter implements HttpClientAdapter {
  _PathAdapter(this.payloads);

  final Map<String, dynamic> payloads;
  final List<String> requestedPaths = <String>[];
  final List<Map<String, dynamic>> requestedQueries = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    requestedQueries.add(Map<String, dynamic>.from(options.queryParameters));
    return ResponseBody.fromString(
      jsonEncode(payloads[options.path]),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
