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

    test('fetchSongs parses the independent playlist songs endpoint', () async {
      final adapter = _PathAdapter(<String, dynamic>{
        '/v1/playlist/songs': <String, dynamic>{
          'list': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'song-1', 'name': '歌曲', 'platform': 'qq'},
          ],
        },
      });
      final client = _createClient(adapter);

      final songs = await client.fetchSongs(request);

      expect(adapter.requestedPaths, <String>['/v1/playlist/songs']);
      expect(songs.single.id, 'song-1');
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

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
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
