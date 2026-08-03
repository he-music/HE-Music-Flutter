import '../../../../shared/models/he_music_models.dart';
import '../entities/playlist_detail_request.dart';
import '../entities/playlist_detail_songs_page_result.dart';

abstract class PlaylistDetailRepository {
  Future<PlaylistInfo> fetchInfo(PlaylistDetailRequest request);

  Future<PlaylistDetailSongsPageResult> fetchSongs(
    PlaylistDetailRequest request, {
    int pageIndex = 1,
    int pageSize = playlistDetailSongsPageSize,
  });
}
