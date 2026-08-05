import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_result.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_section.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_state.dart';
import 'package:he_music_flutter/features/home/presentation/controllers/home_page_controller.dart';
import 'package:he_music_flutter/features/home/presentation/pages/home_page.dart';
import 'package:he_music_flutter/features/home/presentation/providers/home_page_providers.dart';
import 'package:he_music_flutter/features/home/presentation/widgets/discover_home_tab.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/media_grid_card.dart';

void main() {
  testWidgets('home shell renders with two tabs', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildHomeTestApp(apiClient: _TestHomePageApiClient()),
    );
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsWidgets);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('发现'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.text('排行榜'), findsNothing);

    await tester.tap(find.text('发现'));
    await tester.pumpAndSettle();

    expect(find.text('排行榜'), findsOneWidget);
  });

  testWidgets('home discover uses preloaded global platforms', (
    WidgetTester tester,
  ) async {
    final apiClient = _TrackingHomePageApiClient();

    await tester.pumpWidget(_buildHomeTestApp(apiClient: apiClient));

    await tester.pumpAndSettle();

    expect(apiClient.fetchRecommendCallCount, 1);
    expect(apiClient.fetchDiscoverCallCount, 0);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
  });

  testWidgets('home supports horizontal swipe from recommend to discover', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final apiClient = _TrackingHomePageApiClient();

    await tester.pumpWidget(_buildHomeTestApp(apiClient: apiClient));
    await tester.pumpAndSettle();

    expect(apiClient.fetchRecommendCallCount, 1);
    expect(apiClient.fetchDiscoverCallCount, 0);
    expect(find.text('排行榜'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-360, 0));
    await tester.pumpAndSettle();

    expect(apiClient.fetchDiscoverCallCount, 1);
    expect(find.text('排行榜'), findsOneWidget);
  });

  testWidgets('home hides page tabs when only discover is available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildDiscoverTabTestApp());
    await tester.pumpAndSettle();

    expect(find.text('推荐'), findsNothing);
    expect(find.text('发现'), findsNothing);
    expect(find.text('排行榜'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
  });

  testWidgets(
    'home discover does not build far offscreen items on first frame',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDiscoverTabTestApp());

      await tester.pumpAndSettle();

      const visibleSongTitle = '歌曲-0';
      const offscreenSongTitle = '歌曲-19';

      expect(find.text(visibleSongTitle), findsOneWidget);
      expect(find.text(offscreenSongTitle), findsNothing);
    },
  );

  testWidgets(
    'home discover does not depend on scroll-time sliver layout builders',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildDiscoverTabTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(SliverLayoutBuilder), findsNothing);
    },
  );

  testWidgets('home discover song actions include add to user playlist', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildDiscoverTabTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Add to Queue'), findsOneWidget);
    expect(find.text('Add to Playlist'), findsOneWidget);
  });

  testWidgets('home discover resolves album and playlist template covers', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildDiscoverTabTestApp());
    await tester.pumpAndSettle();

    final contentScrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(contentScrollable, findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('专辑块-0'),
      400,
      scrollable: contentScrollable,
    );
    await tester.pumpAndSettle();

    var cards = tester.widgetList<MediaGridCard>(find.byType(MediaGridCard));
    var coverUrls = cards.map((card) => card.coverUrl).toList(growable: false);

    expect(
      coverUrls,
      contains('https://img.example.com/qq/300/300/album-0.jpg'),
    );

    await tester.scrollUntilVisible(
      find.text('歌单块-0'),
      400,
      scrollable: contentScrollable,
    );
    await tester.pumpAndSettle();

    cards = tester.widgetList<MediaGridCard>(find.byType(MediaGridCard));
    coverUrls = cards.map((card) => card.coverUrl).toList(growable: false);

    expect(
      coverUrls,
      contains('https://img.example.com/qq/300/300/playlist-0.jpg'),
    );
  });
}

Widget _buildHomeTestApp({required HomePageApiClient apiClient}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
      homePageApiClientProvider.overrideWithValue(apiClient),
      searchDefaultPlaceholderProvider.overrideWith(
        _TestSearchDefaultPlaceholderController.new,
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: const HomePage(),
    ),
  );
}

Widget _buildDiscoverTabTestApp() {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
      searchDefaultPlaceholderProvider.overrideWith(
        _TestSearchDefaultPlaceholderController.new,
      ),
      homePageControllerProvider.overrideWith(
        _TestLoadedHomePageController.new,
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: DiscoverHomeTab())),
  );
}

final List<OnlinePlatform> _fakeOnlinePlatforms = <OnlinePlatform>[
  OnlinePlatform(
    id: 'qq',
    name: 'QQ音乐',
    shortName: 'QQ',
    status: 1,
    featureSupportFlag:
        PlatformFeatureSupportFlag.getRecommendPage |
        PlatformFeatureSupportFlag.getDiscoverPage,
    imageSizes: <int>[150, 300, 600],
  ),
  OnlinePlatform(
    id: 'disabled',
    name: 'Disabled',
    shortName: 'OFF',
    status: 2,
    featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
  ),
];

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'zh');
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

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return _fakeOnlinePlatforms;
  }

  @override
  Future<List<OnlinePlatform>> ensureLoaded({bool forceRefresh = false}) async {
    return _fakeOnlinePlatforms;
  }
}

class _TestSearchDefaultPlaceholderController
    extends SearchDefaultPlaceholderController {
  @override
  SearchDefaultPlaceholderState build() {
    return const SearchDefaultPlaceholderState();
  }
}

class _TestHomePageApiClient extends HomePageApiClient {
  _TestHomePageApiClient() : super(Dio());

  @override
  Future<HomePageResult> fetchRecommendPage({
    required String platformId,
    required int pageIndex,
  }) async {
    return const HomePageResult(sections: [], hasMore: false);
  }

  @override
  Future<HomePageResult> fetchDiscoverPage({required String platformId}) async {
    return const HomePageResult(sections: [], hasMore: false);
  }
}

class _TrackingHomePageApiClient extends _TestHomePageApiClient {
  int fetchRecommendCallCount = 0;
  int fetchDiscoverCallCount = 0;

  @override
  Future<HomePageResult> fetchRecommendPage({
    required String platformId,
    required int pageIndex,
  }) {
    fetchRecommendCallCount += 1;
    return super.fetchRecommendPage(
      platformId: platformId,
      pageIndex: pageIndex,
    );
  }

  @override
  Future<HomePageResult> fetchDiscoverPage({required String platformId}) {
    fetchDiscoverCallCount += 1;
    return super.fetchDiscoverPage(platformId: platformId);
  }
}

class _TestLoadedHomePageController extends HomePageController {
  @override
  HomePageState build() {
    final platform = OnlinePlatform(
      id: 'qq',
      name: 'QQ音乐',
      shortName: 'QQ',
      status: 1,
      featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
      imageSizes: const <int>[150, 300, 600],
    );
    return HomePageState(
      platforms: <OnlinePlatform>[platform],
      selectedPage: HomePageKind.discover,
      recommend: HomeContentState.initial,
      discover: HomeContentState(
        initialized: true,
        loading: false,
        refreshing: false,
        loadingMore: false,
        selectedPlatformId: 'qq',
        hasMore: false,
        nextPageIndex: 2,
        sections: <HomePageSection>[
          HomePageSection(
            sectionTypeCode: 2,
            sectionType: HomeSectionType.newSongs,
            resourceType: HomeResourceType.song,
            title: '新歌速递',
            songs: List<SongInfo>.generate(
              20,
              (index) => _buildSong(index: index, platformId: 'qq'),
            ),
          ),
          HomePageSection(
            sectionTypeCode: 3,
            sectionType: HomeSectionType.newAlbums,
            resourceType: HomeResourceType.album,
            title: '新碟上架',
            albums: List<AlbumInfo>.generate(
              12,
              (index) => _buildAlbum(index: index, platformId: 'qq'),
            ),
          ),
          HomePageSection(
            sectionTypeCode: 1,
            sectionType: HomeSectionType.generic,
            resourceType: HomeResourceType.playlist,
            title: '推荐歌单',
            playlists: List<PlaylistInfo>.generate(
              12,
              (index) => _buildPlaylist(index: index, platformId: 'qq'),
            ),
          ),
          HomePageSection(
            sectionTypeCode: 1,
            sectionType: HomeSectionType.generic,
            resourceType: HomeResourceType.mv,
            title: '精选视频',
            mvs: List<MvInfo>.generate(
              10,
              (index) => _buildVideo(index: index, platformId: 'qq'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> initialize() async {}
}

SongInfo _buildSong({required int index, required String platformId}) {
  return SongInfo(
    name: '歌曲-$index',
    subtitle: '副标题-$index',
    id: 'song-$index',
    duration: 240,
    mvId: '',
    album: SongInfoAlbumInfo(name: '专辑-$index', id: 'album-$index'),
    artists: <SongInfoArtistInfo>[
      SongInfoArtistInfo(id: 'artist-$index', name: '歌手-$index'),
    ],
    links: const <LinkInfo>[],
    platform: platformId,
    cover: '',
  );
}

AlbumInfo _buildAlbum({required int index, required String platformId}) {
  return AlbumInfo(
    name: '专辑块-$index',
    id: 'album-$index',
    cover: 'https://img.example.com/$platformId/{x}/{y}/album-$index.jpg',
    artists: <SongInfoArtistInfo>[
      SongInfoArtistInfo(id: 'artist-$index', name: '歌手-$index'),
    ],
    songCount: '${10 + index}',
    publishTime: '2026-03-31',
    songs: const <SongInfo>[],
    description: '',
    platform: platformId,
    language: '',
    genre: '',
    type: 0,
    isFinished: true,
    playCount: '${1000 + index}',
  );
}

PlaylistInfo _buildPlaylist({required int index, required String platformId}) {
  return PlaylistInfo(
    name: '歌单块-$index',
    id: 'playlist-$index',
    cover: 'https://img.example.com/$platformId/{x}/{y}/playlist-$index.jpg',
    creator: '创建者-$index',
    songCount: '${20 + index}',
    playCount: '${2000 + index}',
    songs: const <SongInfo>[],
    platform: platformId,
    description: '',
  );
}

MvInfo _buildVideo({required int index, required String platformId}) {
  return MvInfo(
    platform: platformId,
    links: const <LinkInfo>[],
    id: 'video-$index',
    name: '视频尾部-$index',
    cover: '',
    type: 0,
    playCount: '${3000 + index}',
    creator: '作者-$index',
    duration: 180,
    description: '',
  );
}
