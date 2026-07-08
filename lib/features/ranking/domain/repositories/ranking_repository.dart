import '../entities/ranking_detail.dart';
import '../entities/ranking_group.dart';

abstract class RankingRepository {
  Future<List<RankingGroup>> fetchRankingGroups({required String platform});

  Future<RankingDetail> fetchRankingDetail({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 100,
    String? lastId,
  });
}
