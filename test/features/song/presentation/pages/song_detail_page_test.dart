import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/controllers/online_controller.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/widgets/media_grid_card.dart';
import 'package:he_music_flutter/shared/widgets/video_item.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_content.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_field.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_section.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_request.dart';
import 'package:he_music_flutter/features/song/domain/repositories/song_detail_repository.dart';
import 'package:he_music_flutter/features/song/presentation/pages/song_detail_page.dart';
import 'package:he_music_flutter/features/song/presentation/providers/song_detail_providers.dart';
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

  testWidgets('dynamic sections keep order and independent playback queues', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final firstSongs = [
      SongInfo.fromMap({'id': 'a', 'name': '第一首', 'platform': 'qq'}),
      SongInfo.fromMap({'id': 'b', 'name': '第二首', 'platform': 'netease'}),
    ];
    final versionSongs = [
      SongInfo.fromMap({'id': 'c', 'name': '现场版', 'platform': 'kugou'}),
    ];
    final playlistSection = _buildSections().last;
    final mv = MvInfo.fromMap({
      'id': 'mv-live',
      'name': '现场视频',
      'platform': 'netease',
    });
    await tester.pumpWidget(
      _buildTestApp(
        repository: _FakeSongDetailRepository(
          content: SongDetailContent(
            song: _buildDetail().song,
            sections: [
              playlistSection,
              _songSection(firstSongs, title: '服务端推荐标题'),
              SongDetailSection(
                resourceType: 'mv',
                title: '服务端视频标题',
                mvs: [mv],
              ),
              _songSection(versionSongs, title: '服务端版本标题'),
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
    final titles = ['收藏这首歌的歌单', '服务端推荐标题', '服务端视频标题', '服务端版本标题'];
    for (var index = 1; index < titles.length; index++) {
      expect(
        tester.getTopLeft(find.text(titles[index - 1])).dy,
        lessThan(tester.getTopLeft(find.text(titles[index])).dy),
      );
    }
    expect(find.text('查看更多'), findsNothing);
    OnlineSongListItem row(String id) => tester
        .widgetList<OnlineSongListItem>(find.byType(OnlineSongListItem))
        .singleWhere((row) => row.song.id == id);
    row('b').onTap!();
    await tester.pump();
    expect(playerController.lastQueue.map((track) => track.id), ['a', 'b']);
    expect(playerController.lastQueue.map((track) => track.platform), [
      'qq',
      'netease',
    ]);
    expect(playerController.lastStartIndex, 1);
    row('c').onTap!();
    await tester.pump();
    expect(playerController.lastQueue.map((track) => track.id), ['c']);
    expect(playerController.lastQueue.single.platform, 'kugou');
    row('c').onLikeTap!();
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SongDetailPage)),
    );
    final online =
        container.read(onlineControllerProvider.notifier)
            as _TestOnlineController;
    expect(online.favorites.single, (id: 'c', platform: 'kugou', like: true));
    row('c').onMoreTap!();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Queue'));
    await tester.pumpAndSettle();
    expect(playerController.appendedTracks.single.id, 'c');
    expect(playerController.appendedTracks.single.platform, 'kugou');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'album, playlist and video cards navigate with resource identities',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final content = SongDetailContent(
        song: _buildDetail().song,
        sections: [
          _buildSections().last,
          SongDetailSection(
            resourceType: 'album',
            title: '服务端专辑标题',
            albums: [
              AlbumInfo.fromMap({
                'id': 'related-album',
                'name': '相关专辑',
                'platform': 'kuwo',
              }),
            ],
          ),
          SongDetailSection(
            resourceType: 'mv',
            title: '动态视频区块',
            mvs: [
              MvInfo.fromMap({
                'id': 'video-1',
                'name': '视频标题',
                'platform': 'netease',
              }),
            ],
          ),
        ],
      );
      Uri? destination;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SongDetailPage(
              id: 'song-1',
              platform: 'qq',
              title: '测试歌曲',
            ),
          ),
          for (final path in [
            AppRoutes.playlistDetail,
            AppRoutes.videoDetail,
            AppRoutes.albumDetail,
          ])
            GoRoute(
              path: path,
              builder: (context, state) {
                destination = state.uri;
                return const Scaffold(body: Text('资源详情'));
              },
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _buildTestApp(
          repository: _FakeSongDetailRepository(content: content),
          playerController: playerController,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is MediaGridCard &&
              widget.kind == MediaGridCardKind.playlist,
        ),
      );
      await tester.pumpAndSettle();
      expect(destination!.path, AppRoutes.playlistDetail);
      expect(destination!.queryParameters, {
        'id': 'playlist-1',
        'platform': 'qq',
        'title': '相关歌单',
      });
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VideoGridItem));
      await tester.pumpAndSettle();
      expect(destination!.path, AppRoutes.videoDetail);
      expect(destination!.queryParameters, {
        'id': 'video-1',
        'platform': 'netease',
        'title': '视频标题',
      });
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is MediaGridCard && widget.kind == MediaGridCardKind.album,
        ),
      );
      await tester.pumpAndSettle();
      expect(destination!.path, AppRoutes.albumDetail);
      expect(destination!.queryParameters, {
        'id': 'related-album',
        'platform': 'kuwo',
        'title': '相关专辑',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('duplicate titles, missing title and unknown sections are safe', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final song = _buildDetail().song;
    await tester.pumpWidget(
      _buildTestApp(
        repository: _FakeSongDetailRepository(
          content: SongDetailContent(
            song: song,
            sections: [
              const SongDetailSection(resourceType: 'future', title: '不支持的区块'),
              _songSection([]),
              _songSection([song], title: ''),
              _songSection([song], title: '同名区块'),
              _songSection([song], title: '同名区块'),
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
    expect(find.text('相关内容'), findsNothing);
    expect(find.text('同名区块'), findsNWidgets(2));
    expect(find.text('不支持的区块'), findsNothing);
    expect(find.byType(OnlineSongListItem), findsNWidgets(3));
    expect(tester.takeException(), isNull);
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
            content: SongDetailContent(
              song: _buildDetail().song,
              sections: [
                _songSection([
                  ..._buildSections().first.songs,
                  _buildDetail().song,
                ]),
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

  testWidgets('sections render while platform capabilities are pending', (
    tester,
  ) async {
    final platforms = Completer<List<OnlinePlatform>>();
    final repository = _FakeSongDetailRepository();
    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        playerController: playerController,
        platformsController: () => _PendingOnlinePlatformsController(platforms),
        child: const SongDetailPage(
          id: 'song-1',
          platform: 'qq',
          title: '测试歌曲',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('相似歌曲'), findsOneWidget);
    expect(repository.fetchDetailCallCount, 1);
    platforms.complete([]);
    await tester.pump();
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

  testWidgets('song detail hides relation sections when data is empty', (
    tester,
  ) async {
    final repository = _FakeSongDetailRepository(
      content: SongDetailContent(song: _buildDetail().song),
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
  testWidgets(
    'empty fields hide information region while sections still render',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          repository: _FakeSongDetailRepository(
            content: SongDetailContent(
              song: _buildDetail().song,
              sections: _buildSections(),
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
      expect(
        find.byKey(const ValueKey<String>('song-detail-fields')),
        findsNothing,
      );
      expect(find.text('相似歌曲'), findsOneWidget);
      expect(find.text('播放'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'song detail shows backend fields verbatim and shows action area',
    (tester) async {
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
          fields: const [
            SongDetailField(label: '服务端时间', value: '1704067200'),
            SongDetailField(label: '自定义信息', value: ' 国语 '),
          ],
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
      expect(_richTextContains('服务端时间：1704067200'), findsOneWidget);
      expect(_richTextContains('自定义信息： 国语 '), findsOneWidget);
      expect(_richTextContains('2024-01-01'), findsNothing);
      expect(
        tester.getTopLeft(_richTextContains('服务端时间：')).dy,
        lessThan(tester.getTopLeft(_richTextContains('自定义信息：')).dy),
      );
      expect(find.text('播放'), findsOneWidget);
    },
  );

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

  testWidgets('switching songs discards the pending previous detail', (
    tester,
  ) async {
    final repository = _ChangingSongDetailRepository();
    late StateSetter updateSong;
    var id = 'old';
    await tester.pumpWidget(
      _buildTestApp(
        repository: repository,
        playerController: playerController,
        child: StatefulBuilder(
          builder: (context, setState) {
            updateSong = setState;
            return SongDetailPage(id: id, platform: 'qq', title: id);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(GenericDetailLoadingBody), findsOneWidget);
    updateSong(() => id = 'new');
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('新歌曲关联'), findsOneWidget);
    repository.oldDetail.complete(
      SongDetailContent(
        song: _buildDetail().song,
        sections: [
          _songSection([_buildDetail().song], title: '过期关联'),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('新歌曲关联'), findsOneWidget);
    expect(find.text('过期关联'), findsNothing);
    expect(tester.takeException(), isNull);
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
      onlineControllerProvider.overrideWith(_TestOnlineController.new),
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

class _TestOnlineController extends OnlineController {
  final favorites = <({String id, String platform, bool like})>[];

  @override
  Future<void> toggleSongFavorite({
    required String songId,
    required String platform,
    required bool like,
  }) async {
    favorites.add((id: songId, platform: platform, like: like));
  }
}

class _TestPlayerController extends PlayerController {
  PlayerPlaybackState initialState = PlayerPlaybackState.initial(
    const <PlayerTrack>[],
  );
  final List<PlayerTrack> insertNextAndPlayCalls = <PlayerTrack>[];
  List<PlayerTrack> lastQueue = [];
  int lastStartIndex = 0;
  final List<PlayerTrack> appendedTracks = [];

  @override
  Future<void> appendTrack(PlayerTrack track) async {
    appendedTracks.add(track);
  }

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
    lastQueue = queue;
    lastStartIndex = startIndex;
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
        featureSupportFlag: PlatformFeatureSupportFlag.getSongDetail,
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

class _ChangingSongDetailRepository implements SongDetailRepository {
  final oldDetail = Completer<SongDetailContent>();

  @override
  Future<SongDetailContent> fetchDetail(SongDetailRequest request) async {
    if (request.id == 'old') return oldDetail.future;
    return SongDetailContent(
      song: _buildDetail().song,
      sections: [
        _songSection([_buildDetail().song], title: '新歌曲关联'),
      ],
    );
  }
}

class _FakeSongDetailRepository implements SongDetailRepository {
  _FakeSongDetailRepository({
    SongDetailContent? detail,
    SongDetailContent? content,
    this.detailCompleter,
  }) : _detail = detail ?? content ?? _buildDetail();

  final SongDetailContent _detail;
  final Completer<SongDetailContent>? detailCompleter;
  int fetchDetailCallCount = 0;

  @override
  Future<SongDetailContent> fetchDetail(SongDetailRequest request) async {
    fetchDetailCallCount += 1;
    return detailCompleter?.future ?? _detail;
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
    fields: const [
      SongDetailField(label: '发行时间', value: '2024-01-01'),
      SongDetailField(label: '语言', value: '国语'),
    ],
    sections: _buildSections(),
  );
}

SongDetailSection _songSection(
  List<SongInfo> songs, {
  String title = '喜欢听这首歌的也在听',
}) => SongDetailSection(resourceType: 'song', title: title, songs: songs);

List<SongDetailSection> _buildSections() => [
  _songSection(<SongInfo>[
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
  ]),
  const SongDetailSection(
    resourceType: 'playlist',
    title: '收藏这首歌的歌单',
    playlists: <PlaylistInfo>[
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
  ),
];

/// 在 RichText 中查找包含指定文本的 widget（RichText 的 TextSpan 无法被 find.text 匹配）
Finder _richTextContains(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is RichText) {
      return widget.text.toPlainText().contains(text);
    }
    return false;
  });
}
