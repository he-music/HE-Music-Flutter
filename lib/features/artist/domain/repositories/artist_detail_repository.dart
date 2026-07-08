import '../entities/artist_detail_album.dart';
import '../entities/artist_detail_content.dart';
import '../entities/artist_detail_page_chunk.dart';
import '../entities/artist_detail_request.dart';
import '../entities/artist_detail_song.dart';
import '../entities/artist_detail_video.dart';

abstract class ArtistDetailRepository {
  Future<ArtistDetailContent> fetchDetail(ArtistDetailRequest request);

  Future<List<ArtistDetailSong>> fetchSongs(ArtistDetailRequest request);

  Future<ArtistDetailPageChunk<ArtistDetailSong>> fetchSongsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  });

  Future<List<ArtistDetailAlbum>> fetchAlbums(ArtistDetailRequest request);

  Future<ArtistDetailPageChunk<ArtistDetailAlbum>> fetchAlbumsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  });

  Future<List<ArtistDetailVideo>> fetchVideos(ArtistDetailRequest request);

  Future<ArtistDetailPageChunk<ArtistDetailVideo>> fetchVideosPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  });
}
