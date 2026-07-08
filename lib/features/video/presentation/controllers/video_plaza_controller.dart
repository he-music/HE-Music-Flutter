import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/presentation/controllers/filter_plaza_controller.dart';
import '../../data/providers/video_plaza_providers.dart';

class VideoPlazaController extends FilterPlazaController<MvInfo> {
  @override
  Future<List<FilterInfo>> fetchFilters(String platform) {
    return ref
        .read(videoPlazaApiClientProvider)
        .fetchFilters(platform: platform);
  }

  @override
  Future<FilterPlazaPageResult<MvInfo>> fetchContent({
    required String platform,
    required Map<String, String> filters,
    required int pageIndex,
  }) async {
    final result = await ref
        .read(videoPlazaApiClientProvider)
        .fetchVideos(
          platform: platform,
          filters: filters,
          pageIndex: pageIndex,
        );
    return FilterPlazaPageResult(list: result.list, hasMore: result.hasMore);
  }
}
