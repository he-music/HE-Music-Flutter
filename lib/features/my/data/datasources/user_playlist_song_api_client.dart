import 'package:dio/dio.dart';

import '../../../../shared/models/he_music_models.dart';

class UserPlaylistSongApiClient {
  const UserPlaylistSongApiClient(this._dio);

  final Dio _dio;

  Future<void> addSongs({
    required String playlistId,
    required List<IdPlatformInfo> songs,
  }) async {
    await _dio.post(
      '/v1/user/playlist/song',
      data: <String, dynamic>{
        'id': playlistId,
        'songs': songs.map((item) => item.toMap()).toList(growable: false),
      },
    );
  }

  /// 从自建歌单中移除歌曲
  Future<void> removeSongs({
    required String playlistId,
    required List<IdPlatformInfo> songs,
  }) async {
    await _dio.delete(
      '/v1/user/playlist/song',
      data: <String, dynamic>{
        'id': playlistId,
        'songs': songs.map((item) => item.toMap()).toList(growable: false),
      },
    );
  }
}
