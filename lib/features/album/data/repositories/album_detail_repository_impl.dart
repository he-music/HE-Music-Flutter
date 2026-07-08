import '../../domain/entities/album_detail_content.dart';
import '../../domain/entities/album_detail_request.dart';
import '../../domain/repositories/album_detail_repository.dart';
import '../datasources/album_detail_api_client.dart';

class AlbumDetailRepositoryImpl implements AlbumDetailRepository {
  const AlbumDetailRepositoryImpl(this._apiClient);

  final AlbumDetailApiClient _apiClient;

  @override
  Future<AlbumDetailContent> fetchDetail(AlbumDetailRequest request) {
    return _apiClient.fetchDetail(request);
  }
}
