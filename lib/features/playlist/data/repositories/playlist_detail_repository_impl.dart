import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/playlist_detail_request.dart';
import '../../domain/entities/playlist_detail_song.dart';
import '../../domain/repositories/playlist_detail_repository.dart';
import '../datasources/playlist_detail_api_client.dart';

class PlaylistDetailRepositoryImpl implements PlaylistDetailRepository {
  const PlaylistDetailRepositoryImpl(this._apiClient);

  final PlaylistDetailApiClient _apiClient;

  @override
  Future<PlaylistInfo> fetchInfo(PlaylistDetailRequest request) {
    return _apiClient.fetchInfo(request);
  }

  @override
  Future<List<PlaylistDetailSong>> fetchSongs(PlaylistDetailRequest request) {
    return _apiClient.fetchSongs(request);
  }
}
