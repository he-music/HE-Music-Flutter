import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';

void main() {
  final capabilities = <BigInt, int>{
    PlatformFeatureSupportFlag.getSongDetail: 17592186044416,
    PlatformFeatureSupportFlag.listMVFeeds: 35184372088832,
    PlatformFeatureSupportFlag.getSearchDefault: 70368744177664,
    PlatformFeatureSupportFlag.searchLyricSong: 140737488355328,
    PlatformFeatureSupportFlag.searchLyric: 281474976710656,
  };
  for (final entry in capabilities.entries) {
    test('JSON capability ${entry.value} controls only its high bit', () {
      expect(entry.key, BigInt.from(entry.value));
      for (final rawFlag in [entry.value, '${entry.value}']) {
        final payload =
            jsonDecode(
                  jsonEncode({
                    'id': 'qq',
                    'name': 'QQ',
                    'status': 1,
                    'feature_support_flag': rawFlag,
                  }),
                )
                as Map<String, dynamic>;
        final platform = OnlinePlatform.fromMap(payload);
        for (final flag in capabilities.keys) {
          expect(platform.supports(flag), flag == entry.key);
        }
        expect(platform.supports(PlatformFeatureSupportFlag.searchSong), false);
      }
    });
  }
  test('combined JSON high and low bits survive numeric parsing', () {
    final platform = OnlinePlatform.fromMap(
      jsonDecode(
            '{"id":"qq","name":"QQ","status":1,"feature_support_flag":545357767376898}',
          )
          as Map<String, dynamic>,
    );
    for (final flag in capabilities.keys) {
      expect(platform.supports(flag), true);
    }
    expect(platform.supports(PlatformFeatureSupportFlag.searchSong), true);
    expect(platform.supports(PlatformFeatureSupportFlag.searchAlbum), false);
  });
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
