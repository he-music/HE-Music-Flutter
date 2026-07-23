import '../../../../shared/models/he_music_models.dart';
import '../../../playlist/domain/entities/playlist_detail_song.dart';
import '../../domain/entities/user_playlist_detail_request.dart';
import '../../domain/repositories/user_playlist_detail_repository.dart';
import '../datasources/user_playlist_detail_api_client.dart';
import '../datasources/user_playlist_song_api_client.dart';

class UserPlaylistDetailRepositoryImpl implements UserPlaylistDetailRepository {
  const UserPlaylistDetailRepositoryImpl(this._apiClient, this._songApiClient);

  final UserPlaylistDetailApiClient _apiClient;
  final UserPlaylistSongApiClient _songApiClient;

  @override
  Future<PlaylistInfo> fetchInfo(UserPlaylistDetailRequest request) {
    return _apiClient.fetchInfo(request);
  }

  @override
  Future<List<PlaylistDetailSong>> fetchSongs(
    UserPlaylistDetailRequest request,
  ) {
    return _apiClient.fetchSongs(request);
  }

  @override
  Future<void> updatePlaylist({
    required String id,
    required String name,
    required String cover,
    required String description,
  }) {
    return _apiClient.updatePlaylist(
      id: id,
      name: name,
      cover: cover,
      description: description,
    );
  }

  @override
  Future<void> deletePlaylist(String id) {
    return _apiClient.deletePlaylist(id);
  }

  @override
  Future<void> addSongs({
    required String playlistId,
    required List<IdPlatformInfo> songs,
  }) {
    return _songApiClient.addSongs(playlistId: playlistId, songs: songs);
  }

  @override
  Future<void> removeSongs({
    required String playlistId,
    required List<IdPlatformInfo> songs,
  }) {
    return _songApiClient.removeSongs(playlistId: playlistId, songs: songs);
  }
}
