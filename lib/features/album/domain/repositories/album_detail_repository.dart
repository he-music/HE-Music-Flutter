import '../entities/album_detail_content.dart';
import '../entities/album_detail_request.dart';

abstract class AlbumDetailRepository {
  Future<AlbumDetailContent> fetchDetail(AlbumDetailRequest request);
}
