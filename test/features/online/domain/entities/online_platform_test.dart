import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';

void main() {
  test('推荐歌曲集合能力位保持 bit 26 并使用 BigInt 判断', () {
    expect(
      PlatformFeatureSupportFlag.getRecommendSongList,
      BigInt.from(67108864),
    );
    final platform = OnlinePlatform(
      id: 'qq',
      name: 'QQ 音乐',
      shortName: 'QQ',
      status: 1,
      featureSupportFlag:
          PlatformFeatureSupportFlag.getRecommendSongList |
          PlatformFeatureSupportFlag.getDiscoverPage,
    );

    expect(
      platform.supports(PlatformFeatureSupportFlag.getRecommendSongList),
      isTrue,
    );
    expect(
      platform.supports(PlatformFeatureSupportFlag.getRecommendPage),
      isFalse,
    );
  });
}
