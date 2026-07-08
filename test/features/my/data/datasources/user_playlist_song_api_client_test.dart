import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/my/data/datasources/user_playlist_song_api_client.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('addSongs posts playlist id and song id-platform pairs', () async {
    final capture = _DioCapture();
    final client = UserPlaylistSongApiClient(capture.dio);

    await client.addSongs(
      playlistId: 'playlist-123',
      songs: const <IdPlatformInfo>[
        IdPlatformInfo(id: 'song-1', platform: 'qq'),
        IdPlatformInfo(id: 'song-2', platform: 'wy'),
      ],
    );

    expect(capture.method, 'POST');
    expect(capture.path, '/v1/user/playlist/song');
    expect(capture.data, <String, dynamic>{
      'id': 'playlist-123',
      'songs': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'song-1', 'platform': 'qq'},
        <String, dynamic>{'id': 'song-2', 'platform': 'wy'},
      ],
    });
  });
}

class _DioCapture {
  _DioCapture() : dio = Dio() {
    dio.httpClientAdapter = _CaptureAdapter(onRequest: _handle);
  }

  final Dio dio;
  String? method;
  String? path;
  dynamic data;

  void _handle(RequestOptions options) {
    method = options.method;
    path = options.path;
    data = options.data;
  }
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter({required this.onRequest});

  final void Function(RequestOptions options) onRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}
