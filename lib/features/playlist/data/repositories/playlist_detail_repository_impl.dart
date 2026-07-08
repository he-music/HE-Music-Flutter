import '../../domain/entities/playlist_detail_content.dart';
import '../../domain/entities/playlist_detail_request.dart';
import '../../domain/repositories/playlist_detail_repository.dart';
import '../datasources/playlist_detail_api_client.dart';

class PlaylistDetailRepositoryImpl implements PlaylistDetailRepository {
  const PlaylistDetailRepositoryImpl(this._apiClient);

  final PlaylistDetailApiClient _apiClient;

  @override
  Future<PlaylistDetailContent> fetchDetail(PlaylistDetailRequest request) {
    return _apiClient.fetchDetail(request);
  }
}
