import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_comprehensive_result.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_bars.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_models.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_result_page.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/plaza_loading_skeleton.dart';

void main() {
  testWidgets(
    'comprehensive initial load shows section and platform skeletons',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: OnlineSearchResultPage(
            localeCode: 'en',
            selectedType: SearchType.comprehensive,
            onTypeChanged: (_) {},
            loadingPlatforms: true,
            platforms: const <SearchPlatform>[],
            selectedPlatformId: '',
            onPlatformChanged: (_) {},
            availableTypes: const <SearchType>[SearchType.comprehensive],
            loading: true,
            results: const <Map<String, dynamic>>[],
            songResults: const <SearchSongInfo>[],
            searchKeyword: '',
            comprehensiveResult: null,
            error: null,
            initialLoading: true,
            likedSongKeys: const <String>{},
            onTapItem: (_, _) {},
            onTapSongItem: (_) {},
            onLikeSongItem: (_) async {},
            onMoreSongItem: (_) {},
            onMoreSection: (_) {},
            onLoadMore: () async {},
            loadingMore: false,
            hasMore: false,
          ),
        ),
      );

      expect(find.byType(PlazaPlatformTabsSkeleton), findsOneWidget);
      expect(find.byType(OnlineSearchComprehensiveSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('platform refresh keeps the loaded platform tabs visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        child: SearchPlatformBar(
          loading: true,
          platforms: <SearchPlatform>[
            SearchPlatform(
              id: 'qq',
              label: 'QQ',
              available: true,
              featureSupportFlag: BigInt.one,
            ),
          ],
          requiredFeatureFlag: BigInt.one,
          selectedPlatformId: 'qq',
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('QQ'), findsOneWidget);
    expect(find.byType(PlazaPlatformTabsSkeleton), findsNothing);
  });

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
            song: const OnlineComprehensiveSearchSection<SearchSongInfo>(
              items: <SearchSongInfo>[_searchSong],
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
          onTapSongItem: (_) {},
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
              song: const OnlineComprehensiveSearchSection<SearchSongInfo>(),
              playlist:
                  const OnlineComprehensiveSearchSection<
                    Map<String, dynamic>
                  >(),
              album:
                  const OnlineComprehensiveSearchSection<
                    Map<String, dynamic>
                  >(),
              video:
                  const OnlineComprehensiveSearchSection<
                    Map<String, dynamic>
                  >(),
            ),
            likedSongKeys: const <String>{},
            onTapItem: (type, item) {},
            onTapSongItem: (_) {},
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

  testWidgets(
    'song recommendation highlights text and passes nested SongInfo',
    (tester) async {
      SongInfo? tappedSong;
      await tester.pumpWidget(
        _buildApp(
          child: OnlineSearchComprehensiveResult(
            result: const OnlineComprehensiveSearchResult(
              keyword: 'Love',
              bestMatch: <BestMatchRecommendItem>[
                BestMatchRecommendItem(
                  resourceType: 'artist',
                  data: <String, dynamic>{
                    'id': 'artist-1',
                    'platform': 'qq',
                    'name': 'Taylor Swift',
                    'cover': '',
                  },
                ),
                BestMatchRecommendItem(resourceType: 'song', data: _searchSong),
              ],
            ),
            likedSongKeys: const <String>{},
            onTapItem: (_, _) {},
            onTapSongItem: (song) => tappedSong = song,
            onLikeSongItem: (_) async {},
            onMoreSongItem: (_) {},
            onMoreSection: (_) {},
          ),
        ),
      );
      await tester.pump();

      final title = tester.widget<Text>(find.text('Love Story'));
      final titleSpan = title.textSpan! as TextSpan;
      expect(
        titleSpan.children!.whereType<TextSpan>().any(
          (span) => span.style?.fontWeight == FontWeight.w600,
        ),
        isTrue,
      );
      await tester.tap(find.text('Love Story'));
      await tester.pump();
      expect(tappedSong?.id, 'song-1');
    },
  );

  testWidgets('comprehensive song lyric snippet uses one ellipsized line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        child: OnlineSearchComprehensiveResult(
          result: const OnlineComprehensiveSearchResult(
            keyword: 'Love',
            song: OnlineComprehensiveSearchSection<SearchSongInfo>(
              items: <SearchSongInfo>[_searchSongWithLyricSnippet],
            ),
          ),
          likedSongKeys: const <String>{},
          onTapItem: (_, _) {},
          onTapSongItem: (_) {},
          onLikeSongItem: (_) async {},
          onMoreSongItem: (_) {},
          onMoreSection: (_) {},
        ),
      ),
    );
    await tester.pump();

    final snippet = tester.widget<Text>(
      find.byKey(const ValueKey('search-lyric-snippet-song-1|qq')),
    );
    expect(snippet.maxLines, 1);
    expect(snippet.overflow, TextOverflow.ellipsis);
    expect(
      find.byKey(const ValueKey('search-lyric-badge-song-1|qq')),
      findsOneWidget,
    );
  });
}

const _searchSong = SearchSongInfo(
  song: SongInfo(
    name: 'Love Story',
    subtitle: '',
    id: 'song-1',
    duration: 235,
    mvId: '',
    album: SongInfoAlbumInfo(id: 'album-1', name: 'Fearless'),
    artists: <SongInfoArtistInfo>[
      SongInfoArtistInfo(id: 'artist-1', name: 'Taylor Swift'),
    ],
    links: <LinkInfo>[],
    platform: 'qq',
    cover: '',
  ),
  sublist: <SearchSongInfo>[],
  originalType: 0,
  lyricSnippet: '',
  lyric: '',
  matchedKeywords: <String>['Love', 'Taylor Swift'],
);

const _searchSongWithLyricSnippet = SearchSongInfo(
  song: SongInfo(
    name: 'Love Story',
    subtitle: '',
    id: 'song-1',
    duration: 235,
    mvId: '',
    album: SongInfoAlbumInfo(id: 'album-1', name: 'Fearless'),
    artists: <SongInfoArtistInfo>[
      SongInfoArtistInfo(id: 'artist-1', name: 'Taylor Swift'),
    ],
    links: <LinkInfo>[],
    platform: 'qq',
    cover: '',
  ),
  sublist: <SearchSongInfo>[],
  originalType: 0,
  lyricSnippet: 'Long lyric snippet with Love repeated beyond one visible line',
  lyric: '',
  matchedKeywords: <String>['Love'],
);

Widget _buildApp({required Widget child}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
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

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }

  @override
  Future<void> initialize() async {}
}
