import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/presentation/controllers/filter_plaza_controller.dart';
import '../../data/providers/artist_plaza_providers.dart';

class ArtistPlazaController extends FilterPlazaController<ArtistInfo> {
  @override
  Future<List<FilterInfo>> fetchFilters(String platform) {
    return ref
        .read(artistPlazaApiClientProvider)
        .fetchFilters(platform: platform);
  }

  @override
  Future<FilterPlazaPageResult<ArtistInfo>> fetchContent({
    required String platform,
    required Map<String, String> filters,
    required int pageIndex,
  }) async {
    final result = await ref
        .read(artistPlazaApiClientProvider)
        .fetchArtists(
          platform: platform,
          filters: filters,
          pageIndex: pageIndex,
        );
    return FilterPlazaPageResult(list: result.list, hasMore: result.hasMore);
  }
}
