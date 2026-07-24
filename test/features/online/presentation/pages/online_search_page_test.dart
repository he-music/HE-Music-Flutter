import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_icon.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/features/online/data/datasources/search_history_data_source.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_bars.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_models.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_page.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/song_list_component.dart';

void main() {
  testWidgets(
    'online search defaults to comprehensive when platform supports it',
    (tester) async {
      await tester.pumpWidget(
        _buildOnlineSearchApp(initialKeyword: 'Taylor Swift'),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('All'), findsOneWidget);
    },
  );

  testWidgets(
    'online search does not refetch comprehensive result for same key',
    (tester) async {
      final client = _SearchPageOnlineApiClient();
      await tester.pumpWidget(
        _buildOnlineSearchApp(
          initialKeyword: 'Taylor Swift',
          initialType: 'all',
          client: client,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(client.comprehensiveSearchCallCount, 1);

      await tester.tap(find.text('Songs').first);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('All'));
      await tester.pump();
      await tester.pump();

      expect(client.comprehensiveSearchCallCount, 1);
    },
  );

  testWidgets('online search reloads hot keywords when platforms load later', (
    tester,
  ) async {
    final platformsCompleter = Completer<List<OnlinePlatform>>();
    final client = _SearchPageOnlineApiClient();

    await tester.pumpWidget(
      _buildOnlineSearchApp(
        client: client,
        platformsFuture: platformsCompleter.future,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Taylor Swift'), findsOneWidget);
    expect(find.text('平台热词'), findsNothing);

    platformsCompleter.complete(_searchPlatforms);
    await tester.pump();
    await tester.pump();

    expect(find.text('平台热词'), findsOneWidget);
  });

  testWidgets('online search submit requests the skin submit role', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOnlineSearchApp());
    await tester.pump();
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppSkinIcon &&
            widget.role == AppSkinIconRole.searchSubmit,
      ),
      findsOneWidget,
    );
  });

  testWidgets('lyric search entry is hidden without current platform support', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildOnlineSearchApp(initialKeyword: 'Taylor Swift'),
    );
    await tester.pump();
    await tester.pump();

    final bar = tester.widget<SearchTypeBar>(find.byType(SearchTypeBar));
    expect(bar.types, isNot(contains(SearchType.lyric)));
    expect(find.text('Lyrics'), findsNothing);
  });

  testWidgets(
    'supported current platform shows lyric entry last and searches',
    (tester) async {
      final client = _SearchPageOnlineApiClient();
      await tester.pumpWidget(
        _buildOnlineSearchApp(
          initialKeyword: 'Love',
          client: client,
          platformsFuture: Future<List<OnlinePlatform>>.value(<OnlinePlatform>[
            OnlinePlatform(
              id: 'qq',
              name: 'QQ音乐',
              shortName: 'QQ',
              status: 1,
              featureSupportFlag:
                  _searchPlatforms.single.featureSupportFlag |
                  PlatformFeatureSupportFlag.searchLyric,
            ),
          ]),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final bar = tester.widget<SearchTypeBar>(find.byType(SearchTypeBar));
      expect(bar.types.last, SearchType.lyric);

      await tester.ensureVisible(find.text('Lyrics'));
      await tester.tap(find.text('Lyrics'));
      await tester.pump();
      await tester.pump();

      expect(client.lyricSearchCallCount, 1);
      expect(find.text('Love Story'), findsWidgets);
    },
  );

  testWidgets(
    'lyric search pagination follows server page index and has more',
    (tester) async {
      final client = _PagingSearchPageOnlineApiClient();
      await tester.pumpWidget(
        _buildOnlineSearchApp(
          initialKeyword: 'Love',
          initialType: 'lyric',
          client: client,
          platformsFuture: Future<List<OnlinePlatform>>.value(<OnlinePlatform>[
            _lyricSearchPlatform,
          ]),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(client.requestedLyricPages, <int>[1]);

      final songList = tester.widget<SongListComponent>(
        find.byType(SongListComponent),
      );
      expect(songList.hasMore, isTrue);
      await songList.onLoadMore?.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(client.requestedLyricPages, <int>[1, 4]);
      final updatedSongList = tester.widget<SongListComponent>(
        find.byType(SongListComponent),
      );
      expect(updatedSongList.itemCount, 11);
      expect(updatedSongList.hasMore, isFalse);
    },
  );
}

Widget _buildOnlineSearchApp({
  String? initialKeyword,
  String? initialType,
  OnlineApiClient? client,
  Future<List<OnlinePlatform>>? platformsFuture,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(_MiniPlayerTestController.new),
      onlinePlatformsProvider.overrideWith(
        () => _SearchPlatformsController(platformsFuture),
      ),
      onlineApiClientProvider.overrideWithValue(
        client ?? _SearchPageOnlineApiClient(),
      ),
      searchHistoryDataSourceProvider.overrideWithValue(
        const _SearchHistoryDataSourceStub(),
      ),
      searchDefaultPlaceholderProvider.overrideWith(
        _StaticSearchDefaultPlaceholderController.new,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(citySoundCreatorSkin()),
      home: OnlineSearchPage(
        platform: 'qq',
        initialKeyword: initialKeyword,
        initialType: initialType,
      ),
    ),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'en');
  }
}

class _MiniPlayerTestController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'song-1',
        title: '测试歌曲',
        artist: '测试歌手',
        album: '测试专辑',
        platform: 'qq',
        links: <LinkInfo>[
          LinkInfo(
            name: 'SQ',
            quality: 500,
            format: 'mp3',
            size: '3145728',
            url: 'https://example.com/song-1.mp3',
          ),
        ],
      ),
    ]);
  }

  @override
  Future<void> initialize() async {}
}

class _SearchPlatformsController extends OnlinePlatformsController {
  _SearchPlatformsController([this.platformsFuture]);

  final Future<List<OnlinePlatform>>? platformsFuture;

  @override
  Future<List<OnlinePlatform>> build() async {
    return platformsFuture ?? _searchPlatforms;
  }
}

final _searchPlatforms = <OnlinePlatform>[
  OnlinePlatform(
    id: 'qq',
    name: 'QQ音乐',
    shortName: 'QQ',
    status: 1,
    featureSupportFlag:
        PlatformFeatureSupportFlag.getSearchHotkey |
        PlatformFeatureSupportFlag.comprehensiveSearch |
        PlatformFeatureSupportFlag.searchSong |
        PlatformFeatureSupportFlag.searchSinger |
        PlatformFeatureSupportFlag.searchPlaylist,
  ),
];

final _lyricSearchPlatform = OnlinePlatform(
  id: 'qq',
  name: 'QQ音乐',
  shortName: 'QQ',
  status: 1,
  featureSupportFlag:
      _searchPlatforms.single.featureSupportFlag |
      PlatformFeatureSupportFlag.searchLyric,
);

class _SearchPageOnlineApiClient extends OnlineApiClient {
  _SearchPageOnlineApiClient() : super(Dio());

  int comprehensiveSearchCallCount = 0;
  int lyricSearchCallCount = 0;

  @override
  Future<List<String>> fetchHotKeywords({String? platform}) async {
    return const <String>['平台热词'];
  }

  @override
  Future<List<SearchDefaultEntry>> fetchDefaultKeywords({
    String? platform,
    bool silentErrorMessage = false,
  }) async {
    return const <SearchDefaultEntry>[
      SearchDefaultEntry(key: '周杰伦', description: '稻香'),
    ];
  }

  @override
  Future<OnlineComprehensiveSearchResult> comprehensiveSearch({
    required String keyword,
    required String platform,
  }) async {
    comprehensiveSearchCallCount += 1;
    return OnlineComprehensiveSearchResult(
      keyword: keyword,
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
    );
  }

  @override
  Future<OnlineSearchPageResult<Map<String, dynamic>>> searchMusic({
    required String keyword,
    required String platform,
    required String type,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    return OnlineSearchPageResult<Map<String, dynamic>>(
      platform: platform,
      keyword: keyword,
      items: const <Map<String, dynamic>>[],
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalCount: 0,
      hasMore: false,
    );
  }

  @override
  Future<OnlineSearchPageResult<SearchSongInfo>> searchSongs({
    required String keyword,
    required String platform,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    return OnlineSearchPageResult<SearchSongInfo>(
      platform: platform,
      keyword: keyword,
      items: const <SearchSongInfo>[_searchSong],
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalCount: 1,
      hasMore: false,
    );
  }

  @override
  Future<OnlineSearchPageResult<SearchSongInfo>> searchLyrics({
    required String keyword,
    required String platform,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    lyricSearchCallCount += 1;
    return OnlineSearchPageResult<SearchSongInfo>(
      platform: platform,
      keyword: keyword,
      items: const <SearchSongInfo>[_searchSong],
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalCount: 1,
      hasMore: false,
    );
  }
}

class _PagingSearchPageOnlineApiClient extends _SearchPageOnlineApiClient {
  final List<int> requestedLyricPages = <int>[];

  @override
  Future<OnlineSearchPageResult<SearchSongInfo>> searchLyrics({
    required String keyword,
    required String platform,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    requestedLyricPages.add(pageIndex);
    if (pageIndex == 1) {
      return OnlineSearchPageResult<SearchSongInfo>(
        platform: platform,
        keyword: keyword,
        items: List<SearchSongInfo>.generate(
          10,
          (index) => _searchSongForPage(index + 1),
        ),
        pageIndex: 3,
        pageSize: pageSize,
        totalCount: 11,
        hasMore: true,
      );
    }
    return OnlineSearchPageResult<SearchSongInfo>(
      platform: platform,
      keyword: keyword,
      items: <SearchSongInfo>[_searchSongForPage(11)],
      pageIndex: 4,
      pageSize: pageSize,
      totalCount: 11,
      hasMore: false,
    );
  }
}

SearchSongInfo _searchSongForPage(int index) {
  return SearchSongInfo(
    song: SongInfo(
      name: '分页歌曲 $index',
      subtitle: '',
      id: 'page-song-$index',
      duration: 180,
      mvId: '',
      album: const SongInfoAlbumInfo(id: 'album-1', name: '分页专辑'),
      artists: const <SongInfoArtistInfo>[
        SongInfoArtistInfo(id: 'artist-1', name: '分页歌手'),
      ],
      links: const <LinkInfo>[],
      platform: 'qq',
      cover: '',
    ),
    sublist: const <SearchSongInfo>[],
    originalType: 0,
    lyricSnippet: '分页歌词 $index',
    lyric: '',
    matchedKeywords: const <String>['分页'],
  );
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
  lyricSnippet: 'Love Story',
  lyric: 'We were both young when I first saw you',
  matchedKeywords: <String>['Love'],
);

class _SearchHistoryDataSourceStub extends SearchHistoryDataSource {
  const _SearchHistoryDataSourceStub();

  @override
  Future<List<String>> listKeywords() async {
    return const <String>['周杰伦'];
  }

  @override
  Future<List<String>> appendKeyword(String keyword) async {
    return <String>[keyword];
  }

  @override
  Future<void> clearKeywords() async {}
}

class _StaticSearchDefaultPlaceholderController
    extends SearchDefaultPlaceholderController {
  @override
  SearchDefaultPlaceholderState build() {
    return const SearchDefaultPlaceholderState(
      entries: <SearchDefaultEntry>[
        SearchDefaultEntry(key: '周杰伦', description: '稻香'),
      ],
      currentIndex: 0,
    );
  }
}
