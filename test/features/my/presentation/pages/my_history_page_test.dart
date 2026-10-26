import 'dart:async';
import 'dart:typed_data';

import 'package:he_music_flutter/shared/image/local_artwork_bytes_provider.dart';
import 'package:he_music_flutter/shared/widgets/song_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_song_status_state.dart';
import 'package:he_music_flutter/features/my/presentation/controllers/my_history_controller.dart';
import 'package:he_music_flutter/features/my/presentation/pages/my_history_page.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_history_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_history_item.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/shared/widgets/music_detail_slivers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  for (final seconds in [null, 272]) {
    testWidgets('history actions show available duration $seconds', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          items: [
            PlayerHistoryItem(
              id: 'duration',
              title: 'Duration',
              artist: 'Artist',
              album: '',
              artworkUrl: '',
              url: '',
              playedAt: 1,
              platform: 'qq',
              duration: seconds,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await tester.pumpAndSettle();
      expect(
        find.text('04:32'),
        seconds == null ? findsNothing : findsOneWidget,
      );
    });
  }

  testWidgets(
    'brightness changes preserve history rows and locale still updates',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(items: [_historyItem(0)]));
      await tester.pumpAndSettle();
      final row = tester.widget<SongListItem>(find.byType(SongListItem));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyHistoryPage)),
      );
      final config =
          container.read(appConfigProvider.notifier)
              as _TestAppConfigController;
      for (var index = 0; index < 10; index++) {
        config.setLyricPhotoBrightness(0.9 - index * 0.01, persist: false);
        await tester.pump();
        expect(
          tester.widget<SongListItem>(find.byType(SongListItem)),
          same(row),
        );
      }
      config.updateLocale('en');
      await tester.pump();
      expect(find.text('Play History'), findsOneWidget);
    },
  );
  testWidgets(
    'history play all keeps displayed order and resolves online URLs',
    (tester) async {
      final online = PlayerHistoryItem(
        id: 'online-1',
        title: '在线歌曲',
        artist: '歌手',
        album: '专辑',
        albumId: 'album-1',
        artists: const [SongInfoArtistInfo(id: 'artist-1', name: '歌手')],
        artworkUrl: '',
        url: 'https://expired.example/song.mp3',
        playedAt: 1711711711,
        duration: 272,
        platform: 'qq',
        isRadioMode: true,
        currentRadioId: 'radio-1',
      );
      await tester.pumpWidget(_buildTestApp(items: [_historyItem(0), online]));
      await tester.pumpAndSettle();
      expect(find.text('全部播放 2'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyHistoryPage)),
      );
      final player =
          container.read(playerControllerProvider.notifier)
              as _TestPlayerController;
      await tester.tap(find.text('全部播放 2'));
      await tester.pumpAndSettle();
      expect(player.played.map((track) => track.id), ['local-0', 'online-1']);
      expect(player.played.first.url, '/tmp/0.mp3');
      expect(player.played.last.url, isEmpty);
      expect(player.played.last.albumId, 'album-1');
      expect(player.played.last.artists, online.artists);
      expect(player.played.last.duration, const Duration(seconds: 272));
      expect(player.queueSource?.routePath, '/my/history');

      await tester.tap(find.text('在线歌曲'));
      await tester.pumpAndSettle();
      expect(player.singleHistoryItem, same(online));
      final history =
          container.read(myHistoryControllerProvider.notifier)
              as _TestMyHistoryController;
      history.replaceItems([]);
      await tester.pumpAndSettle();
      expect(find.byType(MusicDetailPlayAllHeaderBox), findsNothing);
      expect(find.text('暂无播放历史'), findsOneWidget);
    },
  );

  testWidgets(
    'history reads only visible artwork and playback ticks preserve rows',
    (tester) async {
      final requested = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localArtworkBytesProvider.overrideWith((ref, path) async {
              requested.add(path);
              return null;
            }),
          ],
          child: _buildTestApp(
            items: List.generate(100, (index) => _historyItem(index)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requested, contains('/tmp/0.png'));
      expect(requested.length, lessThan(30));
      final initialRow = tester.widget<SongListItem>(
        find.byType(SongListItem).first,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyHistoryPage)),
      );
      final player =
          container.read(playerControllerProvider.notifier)
              as _TestPlayerController;
      player.tick();
      await tester.pump();
      expect(
        tester.widget<SongListItem>(find.byType(SongListItem).first),
        same(initialRow),
      );
    },
  );

  testWidgets(
    'late artwork from an old history list never overwrites a new row',
    (tester) async {
      final oldArtwork = Completer<Uint8List?>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localArtworkBytesProvider.overrideWith(
              (ref, path) =>
                  path == '/tmp/0.png' ? oldArtwork.future : Future.value(null),
            ),
          ],
          child: _buildTestApp(items: [_historyItem(0)]),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyHistoryPage)),
      );
      final history =
          container.read(myHistoryControllerProvider.notifier)
              as _TestMyHistoryController;
      history.replaceItems([_historyItem(1)]);
      await tester.pumpAndSettle();
      oldArtwork.complete(Uint8List.fromList([1, 2, 3]));
      await tester.pumpAndSettle();
      final row = tester.widget<SongListItem>(find.byType(SongListItem));
      expect(row.data.title, '历史歌曲 1');
      expect(row.data.coverBytes, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('history clear asks for confirmation and cancel keeps history', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        items: const [
          PlayerHistoryItem(
            id: 'song-1',
            title: '测试歌曲',
            artist: '歌手',
            album: '专辑',
            artworkUrl: '',
            url: '',
            playedAt: 1711711711,
            platform: 'qq',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyHistoryPage)),
    );
    final controller =
        container.read(myHistoryControllerProvider.notifier)
            as _TestMyHistoryController;
    await tester.tap(find.byTooltip('清空历史'));
    await tester.pumpAndSettle();
    expect(controller.clearCount, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('测试歌曲'), findsOneWidget);
    await tester.tap(find.byTooltip('清空历史'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '清空历史'));
    await tester.pumpAndSettle();
    expect(controller.clearCount, 1);
    expect(find.text('暂无播放历史'), findsOneWidget);
  });

  for (final supported in [true, false]) {
    testWidgets('历史歌曲曲谱入口遵循平台能力 $supported 并携带歌曲信息', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const MyHistoryPage(),
          ),
          GoRoute(
            path: AppRoutes.songSheetMusic,
            builder: (context, state) => const Text('曲谱目标页'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _buildTestApp(
          items: const [
            PlayerHistoryItem(
              id: 'song-1',
              title: '夜航星',
              artist: '不才',
              album: '',
              artworkUrl: '',
              url: '',
              playedAt: 1711711711,
              platform: 'qq',
            ),
          ],
          router: router,
          sheetMusic: supported,
        ),
      );
      await tester.pumpAndSettle();
      await ProviderScope.containerOf(
        tester.element(find.byType(MyHistoryPage)),
      ).read(onlinePlatformsProvider.future);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('查看曲谱'), supported ? findsOneWidget : findsNothing);
      if (supported) {
        await tester.ensureVisible(find.text('查看曲谱'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('查看曲谱'));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.songSheetMusic);
        expect(router.state.uri.queryParameters, {
          'platform': 'qq',
          'song_id': 'song-1',
          'title': '夜航星',
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('online history item opens unified song actions sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        items: const <PlayerHistoryItem>[
          PlayerHistoryItem(
            id: 'song-1',
            title: '夜航星',
            artist: '不才',
            album: '测试专辑',
            artworkUrl: 'https://example.com/cover.jpg',
            url: '',
            playedAt: 1711711711,
            platform: 'qq',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('播放'), findsOneWidget);
    expect(find.text('下一首播放'), findsOneWidget);
    expect(find.text('添加到播放列表'), findsOneWidget);
  });

  testWidgets('local history item does not expose favorite action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        sheetMusic: true,
        items: const <PlayerHistoryItem>[
          PlayerHistoryItem(
            id: 'local-1',
            title: '本地测试',
            artist: '本地歌手',
            album: '本地专辑',
            artworkUrl: '',
            url: '/tmp/local-1.mp3',
            playedAt: 1711711711,
            platform: 'local',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('下载'), findsNothing);
    expect(find.text('查看曲谱'), findsNothing);
  });
}

PlayerHistoryItem _historyItem(int index) => PlayerHistoryItem(
  id: 'local-$index',
  title: '历史歌曲 $index',
  artist: '歌手',
  album: '专辑',
  artworkUrl: '',
  artworkPath: '/tmp/$index.png',
  url: '/tmp/$index.mp3',
  playedAt: 1711711711,
  platform: 'local',
);

Widget _buildTestApp({
  required List<PlayerHistoryItem> items,
  GoRouter? router,
  bool sheetMusic = false,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      myHistoryControllerProvider.overrideWith(
        () => _TestMyHistoryController(items: items),
      ),
      favoriteSongStatusProvider.overrideWith(
        _TestFavoriteSongStatusController.new,
      ),
      onlinePlatformsProvider.overrideWith(
        () => _TestOnlinePlatformsController(sheetMusic: sheetMusic),
      ),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
    ],
    child: router != null
        ? MaterialApp.router(
            theme: ThemeData(platform: TargetPlatform.android),
            locale: const Locale('zh'),
            supportedLocales: const [Locale('zh'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            routerConfig: router,
          )
        : MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            locale: const Locale('zh'),
            supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const MyHistoryPage(),
          ),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: 'zh',
      apiBaseUrl: 'https://example.com',
      authToken: 'token',
    );
  }

  void updateLocale(String locale) =>
      state = state.copyWith(localeCode: locale);
}

class _TestMyHistoryController extends MyHistoryController {
  _TestMyHistoryController({required this.items});

  final List<PlayerHistoryItem> items;
  int clearCount = 0;
  void replaceItems(List<PlayerHistoryItem> items) => state = AsyncData(items);

  @override
  Future<void> clear() async {
    clearCount++;
    state = const AsyncData([]);
  }

  @override
  Stream<List<PlayerHistoryItem>> build() => Stream.value(items);
}

class _TestFavoriteSongStatusController extends FavoriteSongStatusController {
  @override
  FavoriteSongStatusState build() {
    return const FavoriteSongStatusState(songKeys: <String>{}, ready: true);
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  _TestOnlinePlatformsController({this.sheetMusic = false});

  final bool sheetMusic;
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag:
            PlatformFeatureSupportFlag.getCommentList |
            (sheetMusic
                ? PlatformFeatureSupportFlag.listSheetMusic
                : BigInt.zero),
      ),
    ];
  }
}

class _TestPlayerController extends PlayerController {
  List<PlayerTrack> played = [];
  PlayerQueueSource? queueSource;
  PlayerHistoryItem? singleHistoryItem;

  @override
  Future<void> replaceQueue(
    List<PlayerTrack> queue, {
    int startIndex = 0,
    bool autoplay = true,
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
    PlayerQueueSource? queueSource,
  }) async {
    played = queue;
    this.queueSource = queueSource;
  }

  @override
  Future<void> playHistoryItem(PlayerHistoryItem item) async {
    singleHistoryItem = item;
  }

  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'current-song',
        title: '正在播放',
        artist: '测试歌手',
        platform: 'qq',
      ),
    ]);
  }

  @override
  Future<void> initialize() async {}
  void tick() => state = state.copyWith(position: const Duration(seconds: 1));
}
