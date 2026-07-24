import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_models.dart';

void main() {
  test('search type video maps to mv api type and feature flag', () {
    expect(SearchType.video.apiType, 'mv');
    expect(
      SearchType.video.requiredPlatformFeatureFlag,
      PlatformFeatureSupportFlag.searchMv,
    );
  });

  test('lyric search maps to the int64 lyric capability', () {
    expect(SearchType.lyric.apiType, 'lyric');
    expect(
      SearchType.lyric.requiredPlatformFeatureFlag,
      PlatformFeatureSupportFlag.searchLyricSong,
    );
    expect(
      PlatformFeatureSupportFlag.searchLyricSong,
      BigInt.parse('281474976710656'),
    );
  });
}
