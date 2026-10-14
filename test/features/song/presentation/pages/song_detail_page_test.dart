import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_content.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_relations.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_request.dart';
import 'package:he_music_flutter/features/song/domain/repositories/song_detail_repository.dart';
import 'package:he_music_flutter/features/song/presentation/pages/song_detail_page.dart';
import 'package:he_music_flutter/features/song/presentation/providers/song_detail_providers.dart';
import 'package:he_music_flutter/features/song/presentation/widgets/song_relations_loading_skeleton.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/detail_loading_skeleton.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_song_status_state.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/shared/utils/favorite_song_key.dart';
import 'package:he_music_flutter/shared/widgets/online_song_list_item.dart';

void main() {
  late _TestPlayerController playerController;

  setUp(() {
    playerController = _TestPlayerController();
  });

  testWidgets(
    'brightness changes preserve song detail and locale still updates',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          repository: _FakeSongDetailRepository(),
          playerController: playerController,
          child: const SongDetailPage(
            id: 'song-1',
            platform: 'qq',
            title: '测试歌曲',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SongDetailPage)),
      );
      final config =
          container.read(appConfigProvider.notifier)
              as _TestAppConfigController;
      for (var index = 0; index < 10; index++) {
        config.setLyricPhotoBrightness(0.9 - index * 0.01, persist: false);
        await tester.pump();
        expect(
          tester.widget<CustomScrollView>(find.byType(CustomScrollView)),
          same(scrollView),
        );
      }
      config.updateLocale('en');
      await tester.pump();
      expect(
        tester.widget<CustomScrollView>(find.byType(CustomScrollView)),
        isNot(same(scrollView)),
      );
      expect(find.text('Play'), findsWidgets);
    },
  );

  testWidgets('unrelated playback preserves song detail and header', (
    tester,
  ) async {
    playerController.initialState = PlayerPlaybackState.initial(
      const <PlayerTrack>[
        PlayerTrack(
          id: 'other',
          title: 'Other',
          artist: 'Other',
          platform: 'qq',
        ),
      ],
    );
    await tester.pumpWidget(
      _buildTestApp(
        repository: _FakeSongDetailRepository(),
        playerController: playerController,
        child: const SongDetailPage(
          id: 'song-1',
          platform: 'qq',
          title: '测试歌曲',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final scrollView = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    final header = tester.widget(
      find.byKey(const ValueKey<String>('song-detail-header-compact')),
    );
    playerController.updatePlaying(true);
    await tester.pump();
    expect(
      tester.widget<CustomScrollView>(find.byType(CustomScrollView)),
      same(scrollView),
    );
    expect(
      tester.widget(
        find.byKey(const ValueKey<String>('song-detail-header-compact')),
      ),
      same(header),
    );
    expect(find.text('暂停'), findsNothing);
  });

  testWidgets(
    'related song favorite and playback update only the affected row',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildTestApp(
          repository: _FakeSongDetailRepository(
            relations: SongDetailRelations(
              similarSongs: [
                ..._buildRelations().similarSongs,
                _buildDetail().song,
              ],
            ),
          ),
          playerController: playerController,
          child: const SongDetailPage(
            id: 'song-1',
            platform: 'qq',
            title: '测试歌曲',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SongDetailPage)),
      );
      final favorites =
          container.read(favoriteSongStatusProvider.notifier)
              as _TestFavoriteSongStatusController;
      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      OnlineSongListItem row(String id) => tester
          .widgetList<OnlineSongListItem>(find.byType(OnlineSongListItem))
          .singleWhere((row) => row.song.id == id);
      final unchangedRow = row('song-1');
      favorites.like('similar-1');
      await tester.pump();
      expect(row('similar-1').isLiked, isTrue);
      expect(row('song-1'), same(unchangedRow));
      expect(
        tester.widget<CustomScrollView>(find.byType(CustomScrollView)),
        same(scrollView),
      );
      playerController.showTrack(
        const PlayerTrack(
          id: 'similar-1',
          title: '相似歌曲',
          artist: '歌手',
          platform: 'qq',
        ),
      );
      await tester.pump();
      expect(row('similar-1').isCurrent, isTrue);
      expect(row('song-1'), same(unchangedRow));
      expect(
        tester.widget<CustomScrollView>(find.byType(CustomScrollView)),
        same(scrollView),
      );
    },
  );
  testWidgets('song detail route opens page when params are valid', (
    tester,
  ) async {
    final repository = _FakeSongDetailRepository();

    await tester.pumpWidget(
      _buildRouterApp(
        repository: repository,
        playerController: playerController,
        initialLocation: '/song/detail?id=song-1&platform=qq&title=测试歌曲',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(repository.fetchDetailCallCount, 1);
    expect(find.text('测试歌曲'), findsWidgets);
  });

  testWidgets('song detail back button pops go router page', (tester) async {
    final repository = _FakeSongDetailRepository();

    await tester.pumpWidget(
      _buildRouterApp(
        repository: repository,
        playerController: playerController,
        initialLocation: '/',
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open song detail'));
    await tester.pump();
    await tester.pump();
    expect(find.text('测试歌曲'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump();

    expect(find.text('Open song detail'), findsOneWidget);
    expect(find.byType(SongDetailPage), findsNothing);
  });

  testWidgets('song detail route throws when required params are missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildRouterApp(
        repository: _FakeSongDetailRepository(),
        playerController: playerController,
        initialLocation: '/song/detail?id=song-1',
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isA<StateError>());
  });

  testWidgets('song detail shows loading body before detail resolves', (
    tester,
  ) async {
    final repository = _FakeSongDetailRepository(
      detailCompleter: Completer<SongDetailContent>(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        playerController: playerController,
        child: const SongDetailPage(
          id: 'song-1',
          platform: 'qq',
          title: '测试歌曲',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(GenericDetailLoadingBody), findsOneWidget);
  });

  for (final supported in [true, false]) {
    testWidgets(
      'relation skeleton appears only after support is confirmed ($supported)',
      (tester) async {
        final platformsCompleter = Completer<List<OnlinePlatform>>();
        final relationsCompleter = Completer<SongDetailRelations>();
        final repository = _FakeSongDetailRepository(
          relationsCompleter: relationsCompleter,
        );
        await tester.pumpWidget(
          _buildTestApp(
            repository: repository,
            playerController: playerController,
            platformsController: () =>
                _PendingOnlinePlatformsController(platformsCompleter),
            child: const SongDetailPage(
              id: 'song-1',
              platform: 'qq',
              title: '测试歌曲',
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('测试歌曲'), findsWidgets);
        expect(find.byType(SongRelationsLoadingSkeleton), findsNothing);
        expect(repository.fetchRelationsCallCount, 0);

        platformsCompleter.complete([
          OnlinePlatform(
            id: 'qq',
            name: 'QQ 音乐',
            shortName: 'QQ',
            status: 1,
            featureSupportFlag:
                PlatformFeatureSupportFlag.getSongDetail |
                (supported
                    ? PlatformFeatureSupportFlag.listSongRelations
                    : BigInt.zero),
          ),
        ]);
        await tester.pump();
        await tester.pump();
        expect(
          find.byType(SongRelationsLoadingSkeleton),
          supported ? findsOneWidget : findsNothing,
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(repository.fetchRelationsCallCount, supported ? 1 : 0);

        relationsCompleter.complete(_buildRelations());
        await tester.pump();
        await tester.pump();
        expect(find.byType(SongRelationsLoadingSkeleton), findsNothing);
        expect(find.text('相似歌曲'), supported ? findsWidgets : findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('relation skeleton honors reduced motion on narrow screens', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: SizedBox(width: 240, child: SongRelationsLoadingSkeleton()),
          ),
        ),
      ),
    );
    final fade = find.descendant(
      of: find.byType(SongRelationsLoadingSkeleton),
      matching: find.byType(FadeTransition),
    );
    final initialOpacity = tester.widget<FadeTransition>(fade).opacity.value;
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.widget<FadeTransition>(fade).opacity.value, initialOpacity);
    expect(tester.binding.hasScheduledFrame, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('song detail keeps compact header on wide width', (tester) async {
    final repository = _FakeSongDetailRepository();
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        playerController: playerController,
        child: const SongDetailPage(
          id: 'song-1',
          platform: 'qq',
          title: '测试歌曲',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('song-detail-header-compact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('song-detail-top-bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('song-detail-actions-compact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('song-detail-info-compact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('song-detail-meta-compact')),
      findsOneWidget,
    );

    await tester.binding.setSurfaceSize(const Size(1024, 900));
    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        playerController: playerController,
        child: const SongDetailPage(
          id: 'song-1',
          platform: 'qq',
          title: '测试歌曲',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('song-detail-header-compact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('song-detail-actions-compact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('song-detail-meta-compact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('song-detail-header-wide')),
      findsNothing,
    );
  });

  testWidgets('song detail keeps primary content when relations fail', (
    tester,
  ) async {
    final repository = _FakeSongDetailRepository(relationsError: 'relations');

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        playerController: playerController,
        child: const SongDetailPage(
          id: 'song-1',
          platform: 'qq',
          title: '测试歌曲',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('测试歌曲'), findsWidgets);
    expect(find.text('关联内容加载失败，已显示基础信息'), findsOneWidget);
  });

  testWidgets('song detail hides relation sections when data is empty', (
    tester,
  ) async {
    final repository = _FakeSongDetailRepository(
      relations: const SongDetailRelations(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        playerController: playerController,
        child: const SongDetailPage(
          id: 'song-1',
          platform: 'qq',
          title: '测试歌曲',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('相似歌曲'), findsNothing);
    expect(find.text('其他版本'), findsNothing);
    expect(find.text('相关歌单'), findsNothing);
    expect(find.text('相关 MV'), findsNothing);
  });

  testWidgets('song detail formats publish timestamp and shows action area', (
    tester,
  ) async {
    final repository = _FakeSongDetailRepository(
      detail: SongDetailContent(
        song: SongInfo(
          name: '测试歌曲',
          subtitle: '测试副标题',
          id: 'song-1',
          duration: 215,
          mvId: 'mv-1',
          album: const SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
          artists: const <SongInfoArtistInfo>[
            SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
          ],
          links: const <LinkInfo>[],
          platform: 'qq',
          cover: '',
        ),
        publishTime: '1704067200',
        language: '国语',
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        playerController: playerController,
        child: const SongDetailPage(
          id: 'song-1',
          platform: 'qq',
          title: '测试歌曲',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(_richTextContains('测试歌手'), findsOneWidget);
    expect(_richTextContains('测试专辑'), findsOneWidget);
    expect(_richTextContains('2024-01-01'), findsOneWidget);
    expect(find.text('播放'), findsOneWidget);
  });

  testWidgets('song detail primary play inserts current song and plays now', (
    tester,
  ) async {
    final repository = _FakeSongDetailRepository();

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        playerController: playerController,
        child: const SongDetailPage(
          id: 'song-1',
          platform: 'qq',
          title: '测试歌曲',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('播放').first);
    await tester.pump();

    expect(playerController.insertNextAndPlayCalls, hasLength(1));
    expect(playerController.replaceQueueCallCount, 0);
    expect(playerController.insertNextAndPlayCalls.single.id, 'song-1');
    expect(playerController.insertNextAndPlayCalls.single.title, '测试歌曲');
    expect(playerController.insertNextAndPlayCalls.single.platform, 'qq');
  });

  testWidgets('song detail primary play shows pause for current playing song', (
    tester,
  ) async {
    playerController.initialState =
        PlayerPlaybackState.initial(const <PlayerTrack>[
          PlayerTrack(
            id: 'song-1',
            title: '测试歌曲',
            artist: '测试歌手',
            platform: 'qq',
            links: <LinkInfo>[],
          ),
        ]).copyWith(isPlaying: true);
    final repository = _FakeSongDetailRepository();

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        playerController: playerController,
        child: const SongDetailPage(
          id: 'song-1',
          platform: 'qq',
          title: '测试歌曲',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('暂停'), findsOneWidget);

    await tester.tap(find.text('暂停').first);
    await tester.pump();

    expect(playerController.togglePlayPauseCallCount, 1);
    expect(playerController.insertNextAndPlayCalls, isEmpty);
  });

  testWidgets('song detail primary play resumes current paused song', (
    tester,
  ) async {
    playerController.initialState =
        PlayerPlaybackState.initial(const <PlayerTrack>[
          PlayerTrack(
            id: 'song-1',
            title: '测试歌曲',
            artist: '测试歌手',
            platform: 'qq',
            links: <LinkInfo>[],
          ),
        ]);
    final repository = _FakeSongDetailRepository();

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        playerController: playerController,
        child: const SongDetailPage(
          id: 'song-1',
          platform: 'qq',
          title: '测试歌曲',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('播放'), findsWidgets);

    await tester.tap(find.text('播放').first);
    await tester.pump();

    expect(playerController.togglePlayPauseCallCount, 1);
    expect(playerController.insertNextAndPlayCalls, isEmpty);
  });

  testWidgets('song detail ignores player position updates', (tester) async {
    final repository = _FakeSongDetailRepository();

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        playerController: playerController,
        child: const SongDetailPage(
          id: 'song-1',
          platform: 'qq',
          title: '测试歌曲',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final initialScrollView = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    playerController.updatePosition(const Duration(seconds: 1));
    await tester.pump();

    expect(
      tester.widget<CustomScrollView>(find.byType(CustomScrollView)),
      same(initialScrollView),
    );
  });

  testWidgets(
    'current playback updates the header without rebuilding song detail',
    (tester) async {
      playerController.initialState =
          PlayerPlaybackState.initial(const <PlayerTrack>[
            PlayerTrack(
              id: 'song-1',
              title: '测试歌曲',
              artist: '测试歌手',
              platform: 'qq',
              links: <LinkInfo>[],
            ),
          ]);
      final repository = _FakeSongDetailRepository();

      await tester.pumpWidget(
        _buildTestApp(
          repository: repository,
          playerController: playerController,
          child: const SongDetailPage(
            id: 'song-1',
            platform: 'qq',
            title: '测试歌曲',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final initialScrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(find.text('播放'), findsWidgets);

      playerController.updatePlaying(true);
      await tester.pump();

      expect(
        tester.widget<CustomScrollView>(find.byType(CustomScrollView)),
        same(initialScrollView),
      );
      expect(find.text('暂停'), findsOneWidget);
    },
  );

  testWidgets('song detail more actions shows pause for current playing song', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    playerController.initialState =
        PlayerPlaybackState.initial(const <PlayerTrack>[
          PlayerTrack(
            id: 'song-1',
            title: '测试歌曲',
            artist: '测试歌手',
            platform: 'qq',
            links: <LinkInfo>[],
          ),
        ]).copyWith(isPlaying: true);
    final repository = _FakeSongDetailRepository();

    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        playerController: playerController,
        child: const SongDetailPage(
          id: 'song-1',
          platform: 'qq',
          title: '测试歌曲',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('暂停'), findsOneWidget);
  });
}

Widget _buildTestApp({
  required SongDetailRepository repository,
  required _TestPlayerController playerController,
  required Widget child,
  OnlinePlatformsController Function()? platformsController,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(() => playerController),
      songDetailRepositoryProvider.overrideWithValue(repository),
      onlinePlatformsProvider.overrideWith(
        platformsController ?? _TestOnlinePlatformsController.new,
      ),
      favoriteSongStatusProvider.overrideWith(
        _TestFavoriteSongStatusController.new,
      ),
    ],
    child: MaterialApp(home: child),
  );
}

Widget _buildRouterApp({
  required SongDetailRepository repository,
  required _TestPlayerController playerController,
  required String initialLocation,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: <GoRoute>[
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  context.push('/song/detail?id=song-1&platform=qq&title=测试歌曲'),
              child: const Text('Open song detail'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.songDetail,
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          final platform = state.uri.queryParameters['platform'];
          if (id == null || id.isEmpty) {
            throw StateError('Missing query parameter: id');
          }
          if (platform == null || platform.isEmpty) {
            throw StateError('Missing query parameter: platform');
          }
          return SongDetailPage(
            id: id,
            platform: platform,
            title: state.uri.queryParameters['title'] ?? '',
          );
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(() => playerController),
      songDetailRepositoryProvider.overrideWithValue(repository),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial;
  }

  void updateLocale(String locale) =>
      state = state.copyWith(localeCode: locale);
}

class _TestFavoriteSongStatusController extends FavoriteSongStatusController {
  @override
  FavoriteSongStatusState build() => FavoriteSongStatusState.initial;

  void like(String id) => state = state.copyWith(
    songKeys: {
      ...state.songKeys,
      buildFavoriteSongKey(songId: id, platform: 'qq'),
    },
  );
}

class _TestPlayerController extends PlayerController {
  PlayerPlaybackState initialState = PlayerPlaybackState.initial(
    const <PlayerTrack>[],
  );
  final List<PlayerTrack> insertNextAndPlayCalls = <PlayerTrack>[];
  int replaceQueueCallCount = 0;
  int togglePlayPauseCallCount = 0;

  @override
  PlayerPlaybackState build() {
    return initialState;
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
    replaceQueueCallCount += 1;
  }

  @override
  Future<void> insertNextAndPlay(PlayerTrack track) async {
    insertNextAndPlayCalls.add(track);
  }

  @override
  Future<void> togglePlayPause() async {
    togglePlayPauseCallCount += 1;
  }

  void updatePosition(Duration position) {
    state = state.copyWith(position: position);
  }

  void showTrack(PlayerTrack track) {
    state = state.copyWith(queue: [track], currentIndex: 0);
  }

  void updatePlaying(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);
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
        featureSupportFlag:
            PlatformFeatureSupportFlag.getSongInfo |
            PlatformFeatureSupportFlag.listSongRelations,
      ),
    ];
  }
}

class _PendingOnlinePlatformsController extends OnlinePlatformsController {
  _PendingOnlinePlatformsController(this.completer);

  final Completer<List<OnlinePlatform>> completer;

  @override
  Future<List<OnlinePlatform>> build() => completer.future;
}

class _FakeSongDetailRepository implements SongDetailRepository {
  _FakeSongDetailRepository({
    SongDetailContent? detail,
    SongDetailRelations? relations,
    this.relationsError,
    this.detailCompleter,
    this.relationsCompleter,
  }) : _detail = detail ?? _buildDetail(),
       _relations = relations ?? _buildRelations();

  final SongDetailContent _detail;
  final SongDetailRelations _relations;
  final String? relationsError;
  final Completer<SongDetailContent>? detailCompleter;
  final Completer<SongDetailRelations>? relationsCompleter;

  int fetchDetailCallCount = 0;
  int fetchRelationsCallCount = 0;

  @override
  Future<SongDetailContent> fetchDetail(SongDetailRequest request) async {
    fetchDetailCallCount += 1;
    if (detailCompleter != null) {
      return detailCompleter!.future;
    }
    return _detail;
  }

  @override
  Future<SongDetailRelations> fetchRelations(SongDetailRequest request) async {
    fetchRelationsCallCount += 1;
    if (relationsCompleter != null) {
      return relationsCompleter!.future;
    }
    if (relationsError != null) {
      throw Exception(relationsError);
    }
    return _relations;
  }
}

SongDetailContent _buildDetail() {
  return SongDetailContent(
    song: SongInfo(
      name: '测试歌曲',
      subtitle: '测试副标题',
      id: 'song-1',
      duration: 215,
      mvId: 'mv-1',
      album: const SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
      artists: const <SongInfoArtistInfo>[
        SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
      ],
      links: const <LinkInfo>[],
      platform: 'qq',
      cover: '',
    ),
    publishTime: '2024-01-01',
    language: '国语',
  );
}

SongDetailRelations _buildRelations() {
  return SongDetailRelations(
    similarSongs: <SongInfo>[
      SongInfo(
        name: '相似歌曲',
        subtitle: '',
        id: 'similar-1',
        duration: 201,
        mvId: '',
        album: const SongInfoAlbumInfo(name: '相似专辑', id: 'album-2'),
        artists: const <SongInfoArtistInfo>[
          SongInfoArtistInfo(id: 'artist-2', name: '相似歌手'),
        ],
        links: const <LinkInfo>[],
        platform: 'qq',
        cover: '',
      ),
    ],
    relatedPlaylists: const <PlaylistInfo>[
      PlaylistInfo(
        name: '相关歌单',
        id: 'playlist-1',
        cover: '',
        creator: '歌单作者',
        songCount: '20',
        playCount: '100',
        songs: <SongInfo>[],
        platform: 'qq',
        description: '',
      ),
    ],
  );
}

/// 在 RichText 中查找包含指定文本的 widget（RichText 的 TextSpan 无法被 find.text 匹配）
Finder _richTextContains(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is RichText) {
      return widget.text.toPlainText().contains(text);
    }
    return false;
  });
}
