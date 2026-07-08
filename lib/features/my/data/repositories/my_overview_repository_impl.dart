import '../../domain/entities/my_overview.dart';
import '../../domain/entities/my_summary.dart';
import '../../domain/repositories/my_overview_repository.dart';
import '../datasources/my_overview_api_client.dart';

class MyOverviewRepositoryImpl implements MyOverviewRepository {
  const MyOverviewRepositoryImpl(this._apiClient);

  final MyOverviewApiClient _apiClient;

  @override
  Future<MyOverview> fetchOverview() async {
    final profileFuture = _apiClient.fetchProfile();
    final songFuture = _apiClient.fetchFavouriteSongCount();
    final playlistFuture = _apiClient.fetchFavouritePlaylistCount();
    final artistFuture = _apiClient.fetchFavouriteArtistCount();
    final albumFuture = _apiClient.fetchFavouriteAlbumCount();
    final createdPlaylistFuture = _apiClient.fetchCreatedPlaylistCount();

    final profile = await profileFuture;
    final songCount = await songFuture;
    final playlistCount = await playlistFuture;
    final artistCount = await artistFuture;
    final albumCount = await albumFuture;
    final createdPlaylistCount = await createdPlaylistFuture;

    return MyOverview(
      profile: profile,
      summary: MySummary(
        favoriteSongCount: songCount,
        favoritePlaylistCount: playlistCount,
        favoriteArtistCount: artistCount,
        favoriteAlbumCount: albumCount,
        createdPlaylistCount: createdPlaylistCount,
      ),
    );
  }
}
