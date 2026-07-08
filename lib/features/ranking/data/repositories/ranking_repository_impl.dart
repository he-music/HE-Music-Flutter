import '../../domain/entities/ranking_detail.dart';
import '../../domain/entities/ranking_group.dart';
import '../../domain/repositories/ranking_repository.dart';
import '../datasources/ranking_api_client.dart';

class RankingRepositoryImpl implements RankingRepository {
  const RankingRepositoryImpl(this._apiClient);

  final RankingApiClient _apiClient;

  @override
  Future<List<RankingGroup>> fetchRankingGroups({required String platform}) {
    return _apiClient.fetchRankingGroups(platform: platform);
  }

  @override
  Future<RankingDetail> fetchRankingDetail({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 100,
    String? lastId,
  }) {
    return _apiClient.fetchRankingDetail(
      id: id,
      platform: platform,
      pageIndex: pageIndex,
      pageSize: pageSize,
      lastId: lastId,
    );
  }
}
