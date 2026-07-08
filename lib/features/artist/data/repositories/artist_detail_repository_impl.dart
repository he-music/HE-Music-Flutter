import '../../domain/entities/artist_detail_album.dart';
import '../../domain/entities/artist_detail_content.dart';
import '../../domain/entities/artist_detail_page_chunk.dart';
import '../../domain/entities/artist_detail_request.dart';
import '../../domain/entities/artist_detail_song.dart';
import '../../domain/entities/artist_detail_video.dart';
import '../../domain/repositories/artist_detail_repository.dart';
import '../datasources/artist_detail_api_client.dart';

class ArtistDetailRepositoryImpl implements ArtistDetailRepository {
  const ArtistDetailRepositoryImpl(this._apiClient);

  final ArtistDetailApiClient _apiClient;

  @override
  Future<ArtistDetailContent> fetchDetail(ArtistDetailRequest request) {
    return _apiClient.fetchDetail(request);
  }

  @override
  Future<List<ArtistDetailSong>> fetchSongs(ArtistDetailRequest request) {
    return _apiClient.fetchSongs(request);
  }

  @override
  Future<ArtistDetailPageChunk<ArtistDetailSong>> fetchSongsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) {
    return _apiClient.fetchSongsPage(request, pageIndex: pageIndex);
  }

  @override
  Future<List<ArtistDetailAlbum>> fetchAlbums(ArtistDetailRequest request) {
    return _apiClient.fetchAlbums(request);
  }

  @override
  Future<ArtistDetailPageChunk<ArtistDetailAlbum>> fetchAlbumsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) {
    return _apiClient.fetchAlbumsPage(request, pageIndex: pageIndex);
  }

  @override
  Future<List<ArtistDetailVideo>> fetchVideos(ArtistDetailRequest request) {
    return _apiClient.fetchVideos(request);
  }

  @override
  Future<ArtistDetailPageChunk<ArtistDetailVideo>> fetchVideosPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) {
    return _apiClient.fetchVideosPage(request, pageIndex: pageIndex);
  }
}
