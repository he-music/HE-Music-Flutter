import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/theme/glass/app_glass_scope.dart';
import 'package:he_music_flutter/features/sheet_music/domain/entities/sheet_music_info.dart';
import 'package:he_music_flutter/features/sheet_music/presentation/widgets/sheet_music_list.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/mini_player_bar.dart';
import 'package:he_music_flutter/shared/widgets/app_glass_player_scaffold.dart';
import 'package:he_music_flutter/shared/widgets/detail_page_shell.dart';
import 'package:he_music_flutter/shared/widgets/song_list_component.dart';
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
import 'package:he_music_flutter/features/song/presentation/widgets/song_detail_info_cards.dart';
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

  for (final textScale in [1.0, 2.0]) {
    for (final safeBottom in [0.0, 34.0]) {
      for (final hasTrack in [false, true]) {
        testWidgets(
          'song detail matches shared list scrolling with scale=$textScale safeBottom=$safeBottom track=$hasTrack',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(400, 800));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final showReference = ValueNotifier(true);
            addTearDown(showReference.dispose);
            final song = _buildDetail().song;
            if (hasTrack) {
              playerController.initialState = PlayerPlaybackState.initial([
                PlayerTrack(
                  id: song.id,
                  title: song.title,
                  platform: song.platform,
                ),
              ]);
            }
            await tester.pumpWidget(
              _buildTestApp(
                repository: _FakeSongDetailRepository(
                  content: SongDetailContent(
                    song: song,
                    sections: [
                      SongDetailSection(
                        resourceType: 'sheet_music',
                        title: '歌曲曲谱',
                        sheetMusic: List.generate(
                          14,
                          (index) =>
                              SheetMusicInfo(id: '$index', title: '曲谱 $index'),
                        ),
                      ),
                    ],
                  ),
                ),
                playerController: playerController,
                child: AppGlassScope(
                  enabled: true,
                  mode: AppGlassMode.standard,
                  child: Builder(
                    builder: (context) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        padding: EdgeInsets.only(bottom: safeBottom),
                        viewPadding: EdgeInsets.only(bottom: safeBottom),
                        textScaler: TextScaler.linear(textScale),
                      ),
                      child: AppGlassPlayerScaffold(
                        miniPlayer: MiniPlayerBar(onOpenFullPlayer: () {}),
                        body: ValueListenableBuilder<bool>(
                          valueListenable: showReference,
                          builder: (_, reference, _) => reference
                              ? DetailPageShell(
                                  child: SongListComponent(
                                    enablePaging: false,
                                    itemCount: 14,
                                    itemBuilder: (_, index) => SizedBox(
                                      height: 72,
                                      child: Text('参考歌曲 $index'),
                                    ),
                                  ),
                                )
                              : const SongDetailPage(
                                  id: 'song-1',
                                  platform: 'qq',
                                  title: '测试歌曲',
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            Future<ScrollableState> scrollToEnd(Finder view) async {
              final scroll = tester.state<ScrollableState>(
                find.descendant(of: view, matching: find.byType(Scrollable)),
              );
              // Lazy slivers refine their extent after the last rows are laid out.
              for (var attempt = 0; attempt < 3; attempt++) {
                scroll.position.jumpTo(scroll.position.maxScrollExtent);
                await tester.pumpAndSettle();
              }
              return scroll;
            }

            final referenceView = find.byType(ListView);
            await scrollToEnd(referenceView);
            final referenceViewport = tester.getRect(referenceView);
            final referenceRow = find.ancestor(
              of: find.text('参考歌曲 13'),
              matching: find.byWidgetPredicate(
                (widget) => widget is SizedBox && widget.height == 72,
              ),
            );
            final referenceBottomGap =
                referenceViewport.bottom -
                tester.getBottomLeft(referenceRow).dy;
            showReference.value = false;
            await tester.pumpAndSettle();
            final detailView = find.byType(CustomScrollView);
            final scroll = await scrollToEnd(detailView);
            final viewport = tester.getRect(detailView);
            final lastItem = find.widgetWithText(ListTile, '曲谱 13');
            final lastRect = tester.getRect(lastItem);
            expect(viewport, referenceViewport);
            expect(viewport.bottom, 800);
            // Keep the existing 18px section spacing, then the same safe area
            // used by the album/playlist song list. No extra page spacer.
            expect(
              viewport.bottom - lastRect.bottom,
              closeTo(referenceBottomGap + 18, 0.01),
            );
            if (hasTrack) {
              final player = tester.getRect(find.byType(MiniPlayerBar));
              expect(lastRect.bottom, lessThanOrEqualTo(player.top));
              final delta = player.center.dy - lastRect.center.dy;
              scroll.position.jumpTo(scroll.position.pixels - delta);
              await tester.pumpAndSettle();
              final behindPlayer = tester.getRect(lastItem);
              expect(behindPlayer.overlaps(player), true);
              expect(viewport.contains(behindPlayer.center), true);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'sheet section reuses the list and opens sheets and more with the source song identity',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Uri? destination;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const SongDetailPage(
              id: '000123',
              platform: 'qq',
              title: '入口标题',
            ),
          ),
          for (final path in [
            AppRoutes.songSheetMusic,
            AppRoutes.sheetMusicDetail,
          ])
            GoRoute(
              path: path,
              builder: (_, state) {
                destination = state.uri;
                return const Scaffold(body: Text('曲谱目标页'));
              },
            ),
        ],
      );
      addTearDown(router.dispose);
      final platforms = Completer<List<OnlinePlatform>>()
        ..complete([
          OnlinePlatform(
            id: 'qq',
            name: 'QQ',
            shortName: 'QQ',
            status: 1,
            featureSupportFlag:
                PlatformFeatureSupportFlag.listSheetMusic |
                PlatformFeatureSupportFlag.getSheetMusic,
          ),
        ]);
      await tester.pumpWidget(
        _buildTestApp(
          repository: _FakeSongDetailRepository(
            content: SongDetailContent(
              song: _buildDetail().song,
              sections: [
                _songSection([_buildDetail().song], title: '前面的歌曲'),
                const SongDetailSection(
                  resourceType: 'sheet_music',
                  title: '这首歌的曲谱',
                  sheetMusic: [
                    SheetMusicInfo(
                      id: '0009007199254740993',
                      title: '吉他弹唱谱',
                      platform: 'netease',
                      instruments: ['吉他'],
                      notationTypes: ['六线谱'],
                      originalKey: 'C',
                      pageCount: 3,
                    ),
                  ],
                ),
                _buildSections().last,
              ],
            ),
          ),
          playerController: playerController,
          platformsController: () =>
              _PendingOnlinePlatformsController(platforms),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SheetMusicListSliver), findsOneWidget);
      expect(find.text('吉他 · 六线谱\nC调 · 3页'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('前面的歌曲')).dy,
        lessThan(tester.getTopLeft(find.text('这首歌的曲谱')).dy),
      );
      expect(
        tester.getTopLeft(find.text('这首歌的曲谱')).dy,
        lessThan(tester.getTopLeft(find.text('收藏这首歌的歌单')).dy),
      );
      await tester.tap(find.text('吉他弹唱谱'));
      await tester.pumpAndSettle();
      expect(destination!.path, AppRoutes.sheetMusicDetail);
      expect(destination!.queryParameters, {
        'platform': 'qq',
        'song_id': '000123',
        'id': '0009007199254740993',
        'title': '吉他弹唱谱',
      });
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '更多'));
      await tester.pumpAndSettle();
      expect(destination!.path, AppRoutes.songSheetMusic);
      expect(destination!.queryParameters, {
        'platform': 'qq',
        'song_id': '000123',
        'title': '测试歌曲',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sheet section keeps unsupported or unidentified rows disabled and hides empty sections',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildTestApp(
          repository: _FakeSongDetailRepository(
            content: SongDetailContent(
              song: _buildDetail().song,
              sections: const [
                SongDetailSection(resourceType: 'sheet_music', title: '空曲谱'),
                SongDetailSection(
                  resourceType: 'sheet_music',
                  title: '曲谱区块',
                  sheetMusic: [
                    SheetMusicInfo(id: 'one', title: '未支持详情'),
                    SheetMusicInfo(title: '缺少曲谱标识'),
                  ],
                ),
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
      await tester.pumpAndSettle();
      expect(find.text('空曲谱'), findsNothing);
      for (final title in ['未支持详情', '缺少曲谱标识']) {
        expect(
          tester.widget<ListTile>(find.widgetWithText(ListTile, title)).onTap,
          isNull,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets(
    'header artist and album navigate using the current song identity',
    (tester) async {
      Uri? destination;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const SongDetailPage(
              id: 'song-1',
              platform: 'qq',
              title: '测试歌曲',
            ),
          ),
          for (final path in [AppRoutes.artistDetail, AppRoutes.albumDetail])
            GoRoute(
              path: path,
              builder: (_, state) {
                destination = state.uri;
                return const Scaffold(body: Text('头部资源详情'));
              },
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _buildTestApp(
          repository: _FakeSongDetailRepository(),
          playerController: playerController,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('测试专辑'));
      await tester.pumpAndSettle();
      expect(destination!.path, AppRoutes.albumDetail);
      expect(destination!.queryParameters['id'], 'album-1');
      expect(destination!.queryParameters['platform'], 'qq');
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('测试歌手'));
      await tester.pumpAndSettle();
      expect(destination!.path, AppRoutes.artistDetail);
      expect(destination!.queryParameters['id'], 'artist-1');
      expect(destination!.queryParameters['platform'], 'qq');
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in [
    (width: 240.0, scale: 1.0, glass: false),
    (width: 390.0, scale: 1.0, glass: false),
    (width: 320.0, scale: 2.0, glass: false),
    (width: 240.0, scale: 1.0, glass: true),
    (width: 390.0, scale: 1.0, glass: true),
    (width: 320.0, scale: 2.0, glass: true),
  ]) {
    testWidgets(
      'header places text beside cover and actions below at ${scenario.width}/${scenario.scale} glass=${scenario.glass}',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(scenario.width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final song = SongInfo.fromMap({
          'id': 'song-1',
          'name': '一首名字比较长但需要正常展示的歌曲名称',
          'platform': 'qq',
          'duration': 215,
          'artists': [
            {'id': 'artist-1', 'name': '名字比较长的测试歌手'},
          ],
          'album': {'id': 'album-1', 'name': '名字比较长的测试专辑'},
        });
        await tester.pumpWidget(
          _buildTestApp(
            repository: _FakeSongDetailRepository(
              detail: SongDetailContent(song: song),
            ),
            playerController: playerController,
            child: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(scenario.scale),
              ),
              child: AppGlassScope(
                enabled: scenario.glass,
                mode: AppGlassMode.standard,
                child: const SongDetailPage(
                  id: 'song-1',
                  platform: 'qq',
                  title: '测试歌曲',
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        final cover = tester.getRect(
          find.byKey(const ValueKey<String>('song-detail-cover')),
        );
        final info = tester.getRect(
          find.byKey(const ValueKey<String>('song-detail-info-compact')),
        );
        final hero = tester.getRect(
          find.byKey(const ValueKey<String>('song-detail-hero-row')),
        );
        final actions = tester.getRect(
          find.byKey(const ValueKey<String>('song-detail-actions-compact')),
        );
        final bar = tester.getRect(
          find.byKey(const ValueKey<String>('song-detail-top-bar')),
        );
        expect(info.left, greaterThan(cover.right));
        expect(info.top, cover.top);
        expect(actions.top, greaterThan(hero.bottom));
        expect(
          bar.contains(tester.getCenter(find.byIcon(Icons.more_horiz_rounded))),
          true,
        );
        expect(find.text('名字比较长的测试歌手'), findsOneWidget);
        expect(find.text('名字比较长的测试专辑'), findsOneWidget);
        expect(find.text('来源'), findsOneWidget);
        expect(find.text('QQ音乐'), findsOneWidget);
        expect(find.text('平台'), findsNothing);
        expect(find.text('03:35'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
      expect(find.text('来源'), findsOneWidget);
      expect(find.text('03:35'), findsOneWidget);
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
      expect(find.text('服务端时间'), findsOneWidget);
      expect(find.text('1704067200'), findsOneWidget);
      expect(find.text('自定义信息'), findsOneWidget);
      expect(find.text(' 国语 '), findsOneWidget);
      expect(find.text('2024-01-01'), findsNothing);
      final first = find.byKey(const ValueKey<String>('song-detail-field-0'));
      final second = find.byKey(const ValueKey<String>('song-detail-field-1'));
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
      expect(
        tester.getTopLeft(first).dx,
        lessThan(tester.getTopLeft(second).dx),
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
      final actions = find.byKey(
        const ValueKey<String>('song-detail-actions-row-compact'),
      );
      expect(
        find.descendant(
          of: actions,
          matching: find.byIcon(Icons.play_arrow_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: actions,
          matching: find.byIcon(Icons.favorite_border_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text('收藏歌曲'), findsNothing);
      await tester.tap(find.byTooltip('收藏歌曲'));
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SongDetailPage)),
      );
      final online =
          container.read(onlineControllerProvider.notifier)
              as _TestOnlineController;
      expect(online.favorites.single, (
        id: 'song-1',
        platform: 'qq',
        like: true,
      ));
      final initialHeader = tester.widget(
        find.byKey(const ValueKey<String>('song-detail-header-compact')),
      );
      final initialCards = tester.widget<SongDetailInfoCards>(
        find.byType(SongDetailInfoCards),
      );

      playerController.updatePlaying(true);
      await tester.pump();

      expect(
        tester.widget<CustomScrollView>(find.byType(CustomScrollView)),
        same(initialScrollView),
      );
      expect(find.text('暂停'), findsOneWidget);
      expect(
        find.descendant(
          of: actions,
          matching: find.byIcon(Icons.pause_rounded),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget(
          find.byKey(const ValueKey<String>('song-detail-header-compact')),
        ),
        same(initialHeader),
      );
      expect(
        tester.widget<SongDetailInfoCards>(find.byType(SongDetailInfoCards)),
        same(initialCards),
      );
      (container.read(favoriteSongStatusProvider.notifier)
              as _TestFavoriteSongStatusController)
          .like('song-1');
      await tester.pump();
      expect(
        find.descendant(
          of: actions,
          matching: find.byIcon(Icons.favorite_rounded),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('收藏歌曲'), findsNothing);
      await tester.tap(find.byTooltip('取消收藏'));
      await tester.pump();
      expect(online.favorites.last, (
        id: 'song-1',
        platform: 'qq',
        like: false,
      ));
      expect(
        tester.widget(
          find.byKey(const ValueKey<String>('song-detail-header-compact')),
        ),
        same(initialHeader),
      );
      expect(
        tester.widget<SongDetailInfoCards>(find.byType(SongDetailInfoCards)),
        same(initialCards),
      );
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
        name: 'QQ音乐',
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
