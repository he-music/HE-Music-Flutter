import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_comprehensive_result.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_models.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';

void main() {
  testWidgets('comprehensive result renders sections in fixed order', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        child: OnlineSearchComprehensiveResult(
          result: OnlineComprehensiveSearchResult(
            keyword: 'taylor swift',
            artist: OnlineComprehensiveSearchSection(
              items: const <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'artist-1',
                  'platform': 'qq',
                  'name': 'Taylor Swift',
                  'cover': '',
                  'song_count': 10,
                  'album_count': 5,
                  'mv_count': 1,
                },
              ],
            ),
            song: OnlineComprehensiveSearchSection(
              items: const <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'song-1',
                  'platform': 'qq',
                  'name': 'Love Story',
                  'artist': 'Taylor Swift',
                  'artists': <Map<String, dynamic>>[
                    <String, dynamic>{'id': 'artist-1', 'name': 'Taylor Swift'},
                  ],
                  'album': <String, dynamic>{
                    'id': 'album-1',
                    'name': 'Fearless',
                  },
                  'cover': '',
                  'duration': 235,
                  'links': <Map<String, dynamic>>[],
                },
              ],
            ),
            playlist: OnlineComprehensiveSearchSection(
              items: const <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'playlist-1',
                  'platform': 'qq',
                  'name': 'Taylor Mix',
                  'creator': 'Editor',
                  'cover': '',
                  'song_count': 8,
                },
              ],
            ),
            album: OnlineComprehensiveSearchSection(
              items: const <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'album-1',
                  'platform': 'qq',
                  'name': 'Fearless',
                  'artists': <Map<String, dynamic>>[
                    <String, dynamic>{'id': 'artist-1', 'name': 'Taylor Swift'},
                  ],
                  'cover': '',
                },
              ],
            ),
            video: OnlineComprehensiveSearchSection(
              items: const <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'mv-1',
                  'platform': 'qq',
                  'name': 'Love Story MV',
                  'creator': 'Taylor Swift',
                  'cover': '',
                  'duration': 200,
                  'play_count': 88,
                },
              ],
            ),
          ),
          likedSongKeys: const <String>{},
          onTapItem: (type, item) {},
          onLikeSongItem: (_) async {},
          onMoreSongItem: (_) {},
          onMoreSection: (_) {},
        ),
      ),
    );

    await tester.pump();

    final artists = find.text('Artists');
    final songs = find.text('Songs');
    final playlists = find.text('Playlists');
    final albums = find.text('Albums');
    final videos = find.text('Videos');

    expect(artists, findsOneWidget);
    expect(songs, findsOneWidget);
    expect(playlists, findsOneWidget);
    expect(albums, findsOneWidget);
    expect(videos, findsOneWidget);

    expect(
      tester.getTopLeft(songs).dy,
      lessThan(tester.getTopLeft(artists).dy),
    );
    expect(
      tester.getTopLeft(artists).dy,
      lessThan(tester.getTopLeft(albums).dy),
    );
    expect(
      tester.getTopLeft(albums).dy,
      lessThan(tester.getTopLeft(playlists).dy),
    );
    expect(
      tester.getTopLeft(playlists).dy,
      lessThan(tester.getTopLeft(videos).dy),
    );
  });

  testWidgets(
    'comprehensive result hides empty sections and routes more action',
    (tester) async {
      SearchType? tappedType;

      await tester.pumpWidget(
        _buildApp(
          child: OnlineSearchComprehensiveResult(
            result: OnlineComprehensiveSearchResult(
              keyword: 'taylor swift',
              artist: OnlineComprehensiveSearchSection(
                items: const <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'artist-1',
                    'platform': 'qq',
                    'name': 'Taylor Swift',
                    'cover': '',
                    'song_count': 10,
                    'album_count': 5,
                    'mv_count': 1,
                  },
                ],
                hasMore: true,
              ),
              song: const OnlineComprehensiveSearchSection(),
              playlist: const OnlineComprehensiveSearchSection(),
              album: const OnlineComprehensiveSearchSection(),
              video: const OnlineComprehensiveSearchSection(),
            ),
            likedSongKeys: const <String>{},
            onTapItem: (type, item) {},
            onLikeSongItem: (_) async {},
            onMoreSongItem: (_) {},
            onMoreSection: (type) => tappedType = type,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Artists'), findsOneWidget);
      expect(find.text('Songs'), findsNothing);
      expect(find.text('Playlists'), findsNothing);
      expect(find.text('Albums'), findsNothing);
      expect(find.text('Videos'), findsNothing);
      expect(find.text('More'), findsOneWidget);

      await tester.tap(find.text('More'));
      await tester.pump();

      expect(tappedType, SearchType.artist);
    },
  );
}

Widget _buildApp({required Widget child}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      apiBaseUrl: 'https://example.com',
      localeCode: 'en',
    );
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag:
            PlatformFeatureSupportFlag.comprehensiveSearch |
            PlatformFeatureSupportFlag.searchSong |
            PlatformFeatureSupportFlag.searchPlaylist |
            PlatformFeatureSupportFlag.searchAlbum |
            PlatformFeatureSupportFlag.searchSinger |
            PlatformFeatureSupportFlag.searchMv,
        imageSizes: const <int>[300],
      ),
    ];
  }
}
