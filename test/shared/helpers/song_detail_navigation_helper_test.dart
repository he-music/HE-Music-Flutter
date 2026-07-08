import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/shared/helpers/song_detail_navigation_helper.dart';

void main() {
  group('canOpenSongDetail', () {
    test('returns true for online song without checking feature flag', () {
      expect(
        canOpenSongDetail(
          songId: 'song-1',
          platformId: 'qq',
          platforms: <OnlinePlatform>[
            OnlinePlatform(
              id: 'qq',
              name: 'QQ 音乐',
              shortName: 'QQ',
              status: 1,
              featureSupportFlag: BigInt.zero,
            ),
          ],
        ),
        isTrue,
      );
    });

    test('returns false for local song', () {
      expect(
        canOpenSongDetail(
          songId: 'song-1',
          platformId: 'local',
          platforms: const <OnlinePlatform>[],
        ),
        isFalse,
      );
    });
  });

  group('platform detail support', () {
    final platforms = <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag:
            PlatformFeatureSupportFlag.getAlbumInfo |
            PlatformFeatureSupportFlag.getSingerInfo |
            PlatformFeatureSupportFlag.getCommentList,
      ),
      OnlinePlatform(
        id: 'netease',
        name: '网易云',
        shortName: '网易云',
        status: 1,
        featureSupportFlag: BigInt.zero,
      ),
    ];

    test('album detail follows getAlbumInfo', () {
      expect(
        platformSupportsAlbumDetail(platformId: 'qq', platforms: platforms),
        isTrue,
      );
      expect(
        platformSupportsAlbumDetail(
          platformId: 'netease',
          platforms: platforms,
        ),
        isFalse,
      );
    });

    test('artist detail follows getSingerInfo', () {
      expect(
        platformSupportsArtistDetail(platformId: 'qq', platforms: platforms),
        isTrue,
      );
      expect(
        platformSupportsArtistDetail(
          platformId: 'netease',
          platforms: platforms,
        ),
        isFalse,
      );
    });

    test('comment detail follows getCommentList', () {
      expect(
        platformSupportsSongComment(platformId: 'qq', platforms: platforms),
        isTrue,
      );
      expect(
        platformSupportsSongComment(
          platformId: 'netease',
          platforms: platforms,
        ),
        isFalse,
      );
    });
  });
}
