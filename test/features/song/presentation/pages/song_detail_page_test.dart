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
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/detail_loading_skeleton.dart';

void main() {
  late _TestPlayerController playerController;

  setUp(() {
    playerController = _TestPlayerController();
  });

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
          sublist: const <SongInfo>[],
          originalType: 0,
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
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      playerControllerProvider.overrideWith(() => playerController),
      songDetailRepositoryProvider.overrideWithValue(repository),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
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

class _FakeSongDetailRepository implements SongDetailRepository {
  _FakeSongDetailRepository({
    SongDetailContent? detail,
    SongDetailRelations? relations,
    this.relationsError,
    this.detailCompleter,
  }) : _detail = detail ?? _buildDetail(),
       _relations = relations ?? _buildRelations();

  final SongDetailContent _detail;
  final SongDetailRelations _relations;
  final String? relationsError;
  final Completer<SongDetailContent>? detailCompleter;

  int fetchDetailCallCount = 0;

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
      sublist: const <SongInfo>[],
      originalType: 0,
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
        sublist: const <SongInfo>[],
        originalType: 0,
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
