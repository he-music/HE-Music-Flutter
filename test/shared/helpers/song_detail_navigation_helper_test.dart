import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/shared/helpers/song_detail_navigation_helper.dart';

void main() {
  group('canOpenSongDetail', () {
    test('returns false when getSongDetail is absent', () {
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
        isFalse,
      );
    });
    test(
      'entry requires detail capability, available platform and song identity',
      () {
        for (final enabled in [false, true]) {
          for (final available in [false, true]) {
            for (final id in ['', 'song-1']) {
              expect(
                canOpenSongDetail(
                  songId: id,
                  platformId: 'qq',
                  platforms: [
                    OnlinePlatform(
                      id: 'qq',
                      name: 'QQ',
                      shortName: 'QQ',
                      status: available ? 1 : 0,
                      featureSupportFlag: enabled
                          ? PlatformFeatureSupportFlag.getSongDetail
                          : BigInt.zero,
                    ),
                  ],
                ),
                enabled && available && id.isNotEmpty,
              );
            }
          }
        }
        expect(
          canOpenSongDetail(songId: 's', platformId: 'unknown', platforms: []),
          false,
        );
      },
    );

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
  test('sheet music list and detail capabilities are independent', () {
    for (final platformId in ['qq', 'netease', 'future']) {
      for (final list in [false, true]) {
        for (final detail in [false, true]) {
          for (final status in [0, 1]) {
            final platforms = [
              OnlinePlatform(
                id: platformId,
                name: platformId,
                shortName: platformId,
                status: status,
                featureSupportFlag:
                    (list
                        ? PlatformFeatureSupportFlag.listSheetMusic
                        : BigInt.zero) |
                    (detail
                        ? PlatformFeatureSupportFlag.getSheetMusic
                        : BigInt.zero),
              ),
            ];
            expect(
              canListSongSheetMusic(
                songId: '001',
                platformId: platformId,
                platforms: platforms,
              ),
              list && status == 1,
            );
            expect(
              canGetSongSheetMusic(
                songId: '001',
                platformId: platformId,
                platforms: platforms,
              ),
              detail && status == 1,
            );
            expect(
              canListSongSheetMusic(
                songId: ' ',
                platformId: platformId,
                platforms: platforms,
              ),
              false,
            );
            expect(
              canGetSongSheetMusic(
                songId: '',
                platformId: platformId,
                platforms: platforms,
              ),
              false,
            );
            expect(
              canListSongSheetMusic(
                songId: '001',
                platformId: 'local',
                platforms: platforms,
              ),
              false,
            );
          }
        }
      }
    }
  });
}
