import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_section.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_state.dart';
import 'package:he_music_flutter/features/home/presentation/controllers/home_page_controller.dart';
import 'package:he_music_flutter/features/home/presentation/providers/home_page_providers.dart';
import 'package:he_music_flutter/features/home/presentation/widgets/discover_home_tab.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/radio/data/providers/radio_providers.dart';
import 'package:he_music_flutter/features/radio/domain/repositories/radio_repository.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  testWidgets('三类快捷入口分别进入集合、播放电台和进入歌单', (tester) async {
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: DiscoverHomeTab()),
        ),
        GoRoute(
          path: AppRoutes.recommendSongList,
          builder: (context, state) => Text(
            'song-list:${state.uri.queryParameters}',
            textDirection: TextDirection.ltr,
          ),
        ),
        GoRoute(
          path: AppRoutes.playlistDetail,
          builder: (context, state) => Text(
            'playlist:${state.uri.queryParameters}',
            textDirection: TextDirection.ltr,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    final radioRepository = _RecordingRadioRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          homePageControllerProvider.overrideWith(_TestHomePageController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          searchDefaultPlaceholderProvider.overrideWith(
            _TestSearchPlaceholderController.new,
          ),
          playerControllerProvider.overrideWith(_RecordingPlayerController.new),
          radioRepositoryProvider.overrideWithValue(radioRepository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('推荐歌曲'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.recommendSongList);
    expect(router.state.uri.queryParameters, <String, String>{
      'platform': 'qq',
      'id': 'daily-new',
    });

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('精选歌单'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.playlistDetail);
    expect(router.state.uri.queryParameters, <String, String>{
      'id': 'playlist-1',
      'platform': 'qq',
      'title': '精选歌单',
    });

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('私人电台'));
    await tester.pump();

    expect(router.state.uri.path, '/');
    expect(radioRepository.requestedId, 'radio-1');
    expect(radioRepository.requestedPlatform, 'qq');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiscoverHomeTab)),
    );
    final player =
        container.read(playerControllerProvider.notifier)
            as _RecordingPlayerController;
    expect(player.isRadioMode, isTrue);
    expect(player.currentRadioId, 'radio-1');
    expect(player.currentRadioPlatform, 'qq');
    expect(player.queue.single.id, 'radio-song');
  });
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: 'zh',
      apiBaseUrl: 'https://example.com',
    );
  }
}

class _TestHomePageController extends HomePageController {
  @override
  HomePageState build() {
    final platform = OnlinePlatform(
      id: 'qq',
      name: 'QQ 音乐',
      shortName: 'QQ',
      status: 1,
      featureSupportFlag:
          PlatformFeatureSupportFlag.getRecommendPage |
          PlatformFeatureSupportFlag.getRecommendSongList,
    );
    return HomePageState(
      platforms: <OnlinePlatform>[platform],
      selectedPage: HomePageKind.recommend,
      recommend: const HomeContentState(
        initialized: true,
        loading: false,
        refreshing: false,
        loadingMore: false,
        selectedPlatformId: 'qq',
        sections: <HomePageSection>[
          HomePageSection(
            sectionTypeCode: 6,
            sectionType: HomeSectionType.quickEntries,
            resourceType: null,
            title: '快捷入口',
            entries: <HomePageEntry>[
              HomePageEntry(
                targetType: HomePageEntryTargetType.songList,
                targetId: 'daily-new',
                title: '推荐歌曲',
                subtitle: '每日更新',
                cover: '',
              ),
              HomePageEntry(
                targetType: HomePageEntryTargetType.radio,
                targetId: 'radio-1',
                title: '私人电台',
                subtitle: '',
                cover: '',
              ),
              HomePageEntry(
                targetType: HomePageEntryTargetType.playlist,
                targetId: 'playlist-1',
                title: '精选歌单',
                subtitle: '',
                cover: '',
              ),
            ],
          ),
        ],
        hasMore: false,
        nextPageIndex: 2,
      ),
      discover: HomeContentState.initial,
    );
  }

  @override
  Future<void> initialize() async {}
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.getRecommendPage,
      ),
    ];
  }
}

class _TestSearchPlaceholderController
    extends SearchDefaultPlaceholderController {
  @override
  SearchDefaultPlaceholderState build() {
    return const SearchDefaultPlaceholderState();
  }
}

class _RecordingRadioRepository implements RadioRepository {
  String? requestedId;
  String? requestedPlatform;

  @override
  Future<List<RadioGroupInfo>> fetchGroups({required String platform}) async {
    return const <RadioGroupInfo>[];
  }

  @override
  Future<List<SongInfo>> fetchSongs({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 50,
  }) async {
    requestedId = id;
    requestedPlatform = platform;
    return const <SongInfo>[
      SongInfo(
        name: '电台歌曲',
        subtitle: '',
        id: 'radio-song',
        duration: 1000,
        mvId: '',
        album: null,
        artists: <SongInfoArtistInfo>[],
        links: <LinkInfo>[],
        platform: 'qq',
        cover: '',
      ),
    ];
  }
}

class _RecordingPlayerController extends PlayerController {
  List<PlayerTrack> queue = const <PlayerTrack>[];
  bool isRadioMode = false;
  String? currentRadioId;
  String? currentRadioPlatform;

  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> replaceQueue(
    List<PlayerTrack> queue, {
    int startIndex = 0,
    bool autoplay = true,
    PlayerQueueSource? queueSource,
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  }) async {
    this.queue = queue;
    this.isRadioMode = isRadioMode;
    this.currentRadioId = currentRadioId;
    this.currentRadioPlatform = currentRadioPlatform;
  }
}
