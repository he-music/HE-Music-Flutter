import '../entities/song_detail_content.dart';
import '../entities/song_detail_relations.dart';
import '../entities/song_detail_request.dart';

abstract class SongDetailRepository {
  Future<SongDetailContent> fetchDetail(SongDetailRequest request);

  Future<SongDetailRelations> fetchRelations(SongDetailRequest request);
}
