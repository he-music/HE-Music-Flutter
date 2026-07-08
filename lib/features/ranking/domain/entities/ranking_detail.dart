import 'ranking_info.dart';
import 'ranking_song.dart';

class RankingDetail {
  const RankingDetail({
    required this.info,
    required this.songs,
    required this.hasMore,
    required this.lastId,
    required this.totalCount,
    required this.description,
  });

  final RankingInfo info;
  final List<RankingSong> songs;
  final bool hasMore;
  final String lastId;
  final int totalCount;
  final String description;
}
