import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/playlist_detail_request.dart';
import '../../domain/entities/playlist_detail_songs_page_result.dart';
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
  Future<PlaylistDetailSongsPageResult> fetchSongs(
    PlaylistDetailRequest request, {
    int pageIndex = 1,
    int pageSize = playlistDetailSongsPageSize,
  }) {
    return _apiClient.fetchSongs(
      request,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }
}
