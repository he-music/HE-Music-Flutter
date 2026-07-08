import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_discover_state.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_discover_item.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_discover_section.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_platform.dart';
import 'package:he_music_flutter/features/home/presentation/controllers/home_discover_controller.dart';
import 'package:he_music_flutter/features/home/presentation/pages/home_page.dart';
import 'package:he_music_flutter/features/home/presentation/providers/home_discover_providers.dart';
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
      _buildHomeTestApp(apiClient: _TestHomeDiscoverApiClient()),
    );
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsWidgets);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('排行榜'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
  });

  testWidgets('home discover uses preloaded global platforms', (
    WidgetTester tester,
  ) async {
    final apiClient = _TrackingHomeDiscoverApiClient();

    await tester.pumpWidget(_buildHomeTestApp(apiClient: apiClient));

    await tester.pumpAndSettle();

    expect(apiClient.fetchPlatformsCallCount, 0);
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

  testWidgets('home discover resolves album and playlist template covers', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildDiscoverTabTestApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('专辑块-0'),
      400,
      scrollable: find.byType(Scrollable).first,
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
      scrollable: find.byType(Scrollable).first,
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

Widget _buildHomeTestApp({required HomeDiscoverApiClient apiClient}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
      homeDiscoverApiClientProvider.overrideWithValue(apiClient),
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
      homeDiscoverControllerProvider.overrideWith(
        _TestLoadedHomeDiscoverController.new,
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
    featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
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
}

class _TestSearchDefaultPlaceholderController
    extends SearchDefaultPlaceholderController {
  @override
  SearchDefaultPlaceholderState build() {
    return const SearchDefaultPlaceholderState();
  }
}

class _TestHomeDiscoverApiClient extends HomeDiscoverApiClient {
  _TestHomeDiscoverApiClient() : super(Dio());

  @override
  Future<List<HomePlatform>> fetchPlatforms() async {
    return <HomePlatform>[
      HomePlatform(
        id: 'qq',
        name: 'QQ',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
      ),
    ];
  }

  @override
  Future<List<HomeDiscoverSection>> fetchDiscoverSections(
    String platformId,
  ) async {
    return const <HomeDiscoverSection>[];
  }
}

class _TrackingHomeDiscoverApiClient extends _TestHomeDiscoverApiClient {
  int fetchPlatformsCallCount = 0;

  @override
  Future<List<HomePlatform>> fetchPlatforms() {
    fetchPlatformsCallCount += 1;
    return super.fetchPlatforms();
  }
}

class _TestLoadedHomeDiscoverController extends HomeDiscoverController {
  @override
  HomeDiscoverState build() {
    return HomeDiscoverState(
      loading: false,
      platforms: <HomePlatform>[
        HomePlatform(
          id: 'qq',
          name: 'QQ',
          shortName: 'QQ',
          status: 1,
          featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
        ),
      ],
      selectedPlatformId: 'qq',
      sections: <HomeDiscoverSection>[
        HomeDiscoverSection(
          key: 'new-song',
          titleKey: 'home.section.new_song',
          type: HomeDiscoverItemType.song,
          songs: List<SongInfo>.generate(
            20,
            (index) => _buildSong(index: index, platformId: 'qq'),
          ),
        ),
        HomeDiscoverSection(
          key: 'new-album',
          titleKey: 'home.section.new_album',
          type: HomeDiscoverItemType.album,
          albums: List<AlbumInfo>.generate(
            12,
            (index) => _buildAlbum(index: index, platformId: 'qq'),
          ),
        ),
        HomeDiscoverSection(
          key: 'featured-playlist',
          titleKey: 'home.section.playlist',
          type: HomeDiscoverItemType.playlist,
          playlists: List<PlaylistInfo>.generate(
            12,
            (index) => _buildPlaylist(index: index, platformId: 'qq'),
          ),
        ),
        HomeDiscoverSection(
          key: 'featured-mv',
          titleKey: 'home.section.video',
          type: HomeDiscoverItemType.video,
          videos: List<MvInfo>.generate(
            10,
            (index) => _buildVideo(index: index, platformId: 'qq'),
          ),
        ),
      ],
    );
  }
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
    sublist: const <SongInfo>[],
    originalType: 0,
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
