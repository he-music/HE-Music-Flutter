import '../../../../shared/models/he_music_models.dart';
import '../../../playlist/domain/entities/playlist_detail_song.dart';
import '../entities/user_playlist_detail_request.dart';

abstract interface class UserPlaylistDetailRepository {
  Future<PlaylistInfo> fetchInfo(UserPlaylistDetailRequest request);

  Future<List<PlaylistDetailSong>> fetchSongs(
    UserPlaylistDetailRequest request,
  );

  Future<void> updatePlaylist({
    required String id,
    required String name,
    required String cover,
    required String description,
  });
  Future<void> deletePlaylist(String id);

  /// 向自建歌单添加歌曲
  Future<void> addSongs({
    required String playlistId,
    required List<IdPlatformInfo> songs,
  });

  /// 从自建歌单移除歌曲
  Future<void> removeSongs({
    required String playlistId,
    required List<IdPlatformInfo> songs,
  });
}
