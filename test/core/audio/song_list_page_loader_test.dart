import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/song_list_page_loader.dart';
import 'package:he_music_flutter/shared/models/song_list_pagination.dart';

void main() {
  for (final path in SongListPagination.supportedPaths) {
    test(
      'background pagination uses the page endpoint contract for $path',
      () async {
        final adapter = _Adapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
          ..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final page = await loadSongListPage(
          dio,
          SongListPagination(
            path: path,
            parameters: const {'id': 'a', 'platform': 'qq', 'tab_id': 'latest'},
            nextPageIndex: 2,
            pageSize: path == '/v1/artist/songs' ? 500 : 30,
            hasMore: true,
            lastId: 'cursor-1',
          ),
        );
        final request = adapter.request!;
        expect(request.path, path);
        expect(request.queryParameters['page_index'], 2);
        expect(
          request.queryParameters['page_size'],
          path == '/v1/artist/songs' ? 500 : 30,
        );
        expect(page.songs.single.id, 'song-1');
        expect(page.songs.single.platform, 'qq');
        expect(page.hasMore, isTrue);
        if (path == '/v1/ranking') {
          expect(request.queryParameters['last_id'], 'cursor-1');
          expect(page.lastId, 'cursor-2');
        }
        if (path == '/v1/song/tab/news') {
          expect(request.queryParameters['tab_id'], 'latest');
        }
        if (path == '/v1/user/playlist/songs') {
          expect(request.queryParameters.containsKey('platform'), isFalse);
        }
      },
    );
  }
}

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'a',
        'name': 'A',
        options.path == '/v1/ranking' ? 'songs' : 'list': [
          {'id': 'song-1', 'name': 'Song', 'platform': 'qq'},
        ],
        'has_more': true,
        'last_id': 'cursor-2',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
