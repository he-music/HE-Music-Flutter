import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/features/home/domain/entities/recommend_song_list_info.dart';
import 'package:he_music_flutter/features/home/domain/entities/recommend_song_list_request.dart';
import 'package:he_music_flutter/features/home/presentation/pages/recommend_song_list_page.dart';
import 'package:he_music_flutter/features/home/presentation/providers/home_page_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/song_batch_action_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:he_music_flutter/shared/providers/song_sort_providers.dart';
import 'package:he_music_flutter/shared/utils/song_sort.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('详情使用接口数据并支持播放全部和点击歌曲播放', (tester) async {
    final apiClient = _TestHomePageApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          homePageApiClientProvider.overrideWithValue(apiClient),
          playerControllerProvider.overrideWith(_RecordingPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: const MaterialApp(
          home: RecommendSongListPage(id: 'daily-new', platform: 'qq'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(apiClient.requests.single.id, 'daily-new');
    expect(apiClient.requests.single.platform, 'qq');
    expect(find.text('接口推荐标题'), findsWidgets);
    expect(find.text('接口推荐描述'), findsOneWidget);
    expect(find.text('歌曲一'), findsOneWidget);
    expect(find.text('歌曲二'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RecommendSongListPage)),
    );
    final player =
        container.read(playerControllerProvider.notifier)
            as _RecordingPlayerController;

    await tester.tap(find.byIcon(Icons.play_circle_fill_rounded));
    await tester.pump();
    await tester.tap(find.text('歌曲二'));
    await tester.pump();

    expect(player.startIndexes, <int>[0, 1]);
    expect(player.lastQueue.map((track) => track.id), <String>[
      'song-1',
      'song-2',
    ]);
    expect(player.lastSource?.routePath, AppRoutes.recommendSongList);
    expect(player.lastSource?.queryParameters, <String, String>{
      'platform': 'qq',
      'id': 'daily-new',
    });
    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();
    // SongInfo 的接口时长以秒为单位，1000 秒应显示为 16:40。
    expect(find.text('16:40'), findsOneWidget);
    Navigator.of(tester.element(find.text('16:40'))).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('详情支持批量选择并播放选中歌曲', (tester) async {
    final apiClient = _TestHomePageApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          homePageApiClientProvider.overrideWithValue(apiClient),
          playerControllerProvider.overrideWith(_RecordingPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: const MaterialApp(
          home: RecommendSongListPage(id: 'daily-new', platform: 'qq'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RecommendSongListPage)),
    );
    final player =
        container.read(playerControllerProvider.notifier)
            as _RecordingPlayerController;

    await tester.tap(find.text('Batch'));
    await tester.pump();
    expect(find.byType(SongBatchActionBar), findsOneWidget);

    await tester.tap(find.text('歌曲二'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(player.startIndexes, <int>[0]);
    expect(player.lastQueue.map((track) => track.id), <String>['song-2']);
    expect(find.byType(SongBatchActionBar), findsNothing);
  });
  testWidgets(
    'restored title order is shared by display, song taps and play all',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        SongSortPreferenceController.storageKey:
            '{"field":"title","ascending":true}',
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_TestAppConfigController.new),
            homePageApiClientProvider.overrideWithValue(
              _TestHomePageApiClient(),
            ),
            playerControllerProvider.overrideWith(
              _RecordingPlayerController.new,
            ),
            onlinePlatformsProvider.overrideWith(
              _TestOnlinePlatformsController.new,
            ),
          ],
          child: const MaterialApp(
            home: RecommendSongListPage(id: 'daily-new', platform: 'qq'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('歌曲二')).dy,
        lessThan(tester.getTopLeft(find.text('歌曲一')).dy),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RecommendSongListPage)),
      );
      final player =
          container.read(playerControllerProvider.notifier)
              as _RecordingPlayerController;
      expect(player.startIndexes, isEmpty);
      await tester.tap(find.text('歌曲一'));
      await tester.pump();
      expect(player.startIndexes, [1]);
      expect(player.lastQueue.map((track) => track.id), ['song-2', 'song-1']);
      await tester.tap(find.byIcon(Icons.play_circle_fill_rounded));
      await tester.pump();
      expect(player.startIndexes, [1, 0]);
      expect(player.lastQueue.map((track) => track.id), ['song-2', 'song-1']);
      await container
          .read(songSortPreferenceProvider.notifier)
          .setPreference(const SongSortPreference());
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('歌曲一')).dy,
        lessThan(tester.getTopLeft(find.text('歌曲二')).dy),
      );
      expect(player.startIndexes, [1, 0]);
      expect(player.syncedQueues, isEmpty);
      await tester.tap(find.byKey(const Key('song-sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('标题'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('确认'));
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(player.syncedQueues, [
        ['song-2', 'song-1'],
      ]);
      expect(player.startIndexes, [1, 0]);
    },
  );
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

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: BigInt.zero,
      ),
    ];
  }
}

class _TestHomePageApiClient extends HomePageApiClient {
  _TestHomePageApiClient() : super(Dio());

  final List<RecommendSongListRequest> requests = [];

  @override
  Future<RecommendSongListInfo> fetchRecommendSongList(
    RecommendSongListRequest request,
  ) async {
    requests.add(request);
    return const RecommendSongListInfo(
      id: 'daily-new',
      title: '接口推荐标题',
      cover: '',
      description: '接口推荐描述',
      songs: <SongInfo>[
        SongInfo(
          name: '歌曲一',
          subtitle: '歌手',
          id: 'song-1',
          duration: 1000,
          mvId: '',
          album: null,
          artists: <SongInfoArtistInfo>[],
          links: <LinkInfo>[],
          platform: 'qq',
          cover: '',
        ),
        SongInfo(
          name: '歌曲二',
          subtitle: '歌手',
          id: 'song-2',
          duration: 1000,
          mvId: '',
          album: null,
          artists: <SongInfoArtistInfo>[],
          links: <LinkInfo>[],
          platform: 'qq',
          cover: '',
        ),
      ],
    );
  }
}

class _RecordingPlayerController extends PlayerController {
  final List<int> startIndexes = [];
  List<PlayerTrack> lastQueue = const <PlayerTrack>[];
  PlayerQueueSource? lastSource;
  final List<List<String>> syncedQueues = [];

  @override
  Future<bool> reorderQueueForSource(
    List<IdPlatformInfo> orderedSongs, {
    required PlayerQueueSource source,
  }) async {
    syncedQueues.add(orderedSongs.map((song) => song.id).toList());
    return true;
  }

  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
  }

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
    startIndexes.add(startIndex);
    lastQueue = queue;
    lastSource = queueSource;
  }
}
