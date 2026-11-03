import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/router/platform_route_policy.dart';

void main() {
  test('local playback and downloads do not require platform metadata', () {
    for (final location in [
      AppRoutes.collection,
      AppRoutes.library,
      AppRoutes.downloads,
      AppRoutes.downloadedMusic,
      AppRoutes.localGenre,
      AppRoutes.localMetadataEdit,
      AppRoutes.player,
      AppRoutes.my,
      AppRoutes.settings,
    ]) {
      expect(
        canOpenWithoutPlatforms(Uri.parse(location)),
        isTrue,
        reason: location,
      );
    }
  });

  test('online discovery, search and detail deep links remain gated', () {
    for (final location in [
      AppRoutes.home,
      AppRoutes.onlineSearch,
      AppRoutes.rankingList,
      AppRoutes.playlistPlaza,
      AppRoutes.artistDetail,
      AppRoutes.albumDetail,
    ]) {
      expect(
        canOpenWithoutPlatforms(Uri.parse(location)),
        isFalse,
        reason: location,
      );
    }
    expect(
      canOpenWithoutPlatforms(
        Uri(
          path: AppRoutes.albumDetail,
          queryParameters: {'platform': 'local'},
        ),
      ),
      isTrue,
    );
    expect(
      canOpenWithoutPlatforms(
        Uri(path: AppRoutes.albumDetail, queryParameters: {'platform': 'qq'}),
      ),
      isFalse,
    );
  });
  test('root browsing aliases keep local and online startup policies', () {
    expect(
      canOpenWithoutPlatforms(
        Uri.parse('${AppRoutes.rootBrowsePrefix}${AppRoutes.library}'),
      ),
      isTrue,
    );
    expect(
      canOpenWithoutPlatforms(
        Uri.parse('${AppRoutes.rootBrowsePrefix}${AppRoutes.downloads}'),
      ),
      isTrue,
    );
    expect(
      canOpenWithoutPlatforms(
        Uri.parse('${AppRoutes.rootBrowsePrefix}${AppRoutes.onlineSearch}'),
      ),
      isFalse,
    );
    expect(
      canOpenWithoutPlatforms(
        Uri.parse(
          '${AppRoutes.rootBrowsePrefix}${AppRoutes.albumDetail}?platform=local',
        ),
      ),
      isTrue,
    );
  });
}
