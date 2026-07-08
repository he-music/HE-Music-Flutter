import '../../../../shared/models/he_music_models.dart';
import '../../domain/repositories/radio_repository.dart';
import '../datasources/radio_api_client.dart';

/// RadioRepository 的实现，委托给 RadioApiClient。
class RadioRepositoryImpl implements RadioRepository {
  const RadioRepositoryImpl(this._apiClient);

  final RadioApiClient _apiClient;

  @override
  Future<List<RadioGroupInfo>> fetchGroups({required String platform}) {
    return _apiClient.fetchGroups(platform: platform);
  }

  @override
  Future<List<SongInfo>> fetchSongs({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 50,
  }) {
    return _apiClient.fetchSongs(
      id: id,
      platform: platform,
      pageIndex: pageIndex,
      pageSize: pageSize,
    );
  }
}
