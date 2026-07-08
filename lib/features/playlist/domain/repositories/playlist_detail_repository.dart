import '../entities/playlist_detail_content.dart';
import '../entities/playlist_detail_request.dart';

abstract class PlaylistDetailRepository {
  Future<PlaylistDetailContent> fetchDetail(PlaylistDetailRequest request);
}
