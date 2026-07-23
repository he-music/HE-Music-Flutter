import '../../../../shared/models/he_music_models.dart';
import '../entities/playlist_detail_request.dart';
import '../entities/playlist_detail_song.dart';

abstract class PlaylistDetailRepository {
  Future<PlaylistInfo> fetchInfo(PlaylistDetailRequest request);

  Future<List<PlaylistDetailSong>> fetchSongs(PlaylistDetailRequest request);
}
