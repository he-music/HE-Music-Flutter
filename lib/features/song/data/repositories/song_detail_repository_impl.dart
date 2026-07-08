import '../../domain/entities/song_detail_content.dart';
import '../../domain/entities/song_detail_relations.dart';
import '../../domain/entities/song_detail_request.dart';
import '../../domain/repositories/song_detail_repository.dart';
import '../datasources/song_detail_api_client.dart';

class SongDetailRepositoryImpl implements SongDetailRepository {
  const SongDetailRepositoryImpl(this._apiClient);

  final SongDetailApiClient _apiClient;

  @override
  Future<SongDetailContent> fetchDetail(SongDetailRequest request) {
    return _apiClient.fetchDetail(request);
  }

  @override
  Future<SongDetailRelations> fetchRelations(SongDetailRequest request) {
    return _apiClient.fetchRelations(request);
  }
}
