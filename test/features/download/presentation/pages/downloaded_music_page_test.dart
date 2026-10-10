import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_glass_mode.dart';
import 'package:he_music_flutter/app/router/app_router.dart';
import 'package:he_music_flutter/features/download/domain/entities/download_state.dart';
import 'package:he_music_flutter/features/download/presentation/controllers/download_controller.dart';
import 'package:he_music_flutter/features/download/domain/entities/download_task.dart';
import 'package:he_music_flutter/features/download/domain/entities/downloaded_song.dart';
import 'package:he_music_flutter/features/download/domain/repositories/downloaded_music_repository.dart';
import 'package:he_music_flutter/features/download/presentation/pages/download_page.dart';
import 'package:he_music_flutter/features/download/presentation/providers/download_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/widgets/song_list_item.dart';

void main() {
  testWidgets(
    'legacy downloaded links and task URLs open the unified download page',
    (tester) async {
      final router = createAppRouter('/downloads/music');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(() => _Config('zh')),
            playerControllerProvider.overrideWith(_Player.new),
            downloadedMusicRepositoryProvider.overrideWithValue(_Repository()),
            downloadControllerProvider.overrideWith(_Tasks.new),
          ],
          child: MaterialApp.router(
            locale: const Locale('zh'),
            supportedLocales: const [Locale('zh'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DownloadPage), findsOneWidget);
      expect(find.text('夜曲'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/downloads');
      router.go('/downloads?tab=tasks');
      await tester.pumpAndSettle();
      expect(find.text('暂无下载任务。'), findsOneWidget);
      expect(find.text('夜曲'), findsNothing);
      router.go('/downloads?tab=downloaded');
      await tester.pumpAndSettle();
      expect(find.text('夜曲'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    },
  );

  testWidgets(
    'download page tabs show all downloaded songs and allow direct playback',
    (tester) async {
      final player = _Player();
      await tester.pumpWidget(_app(player));
      await tester.pumpAndSettle();
      expect(find.text('已下载'), findsOneWidget);
      expect(find.text('下载任务'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byKey(const ValueKey('download-tab-tasks')));
      await tester.pumpAndSettle();
      expect(find.text('暂无下载任务。'), findsOneWidget);
      expect(find.text('夜曲'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('download-tab-downloaded')));
      await tester.pumpAndSettle();
      expect(find.text('失效歌曲'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('downloaded-song-first')),
          matching: find.text('夜曲'),
        ),
      );
      await tester.pump();
      expect(player.played.single.path, '/tmp/first.mp3');
      expect(player.played.single.platform, 'qq');
      expect(
        tester
            .widget<SongListItem>(
              find.byKey(const ValueKey('downloaded-song-first')),
            )
            .data
            .isCurrent,
        isTrue,
      );
      expect(
        tester
            .widget<SongListItem>(
              find.byKey(const ValueKey('downloaded-song-missing')),
            )
            .data
            .isCurrent,
        isFalse,
      );
    },
  );

  testWidgets(
    'redownload from the library switches to tasks without pushing a page',
    (tester) async {
      final tasks = _Tasks();
      await tester.pumpWidget(_app(_Player(), tasks: tasks));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz_rounded).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('重新下载'));
      await tester.pumpAndSettle();
      expect(tasks.redownloaded?.id, 'missing');
      expect(find.byType(DownloadPage), findsOneWidget);
      expect(find.text('暂无下载任务。'), findsOneWidget);
    },
  );

  testWidgets(
    'play all excludes unavailable files and retains platform identity',
    (tester) async {
      final player = _Player();
      await tester.pumpWidget(_app(player));
      await tester.pumpAndSettle();
      expect(find.text('全部播放 1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('downloaded-music-play-all')));
      await tester.pump();
      expect(player.played, hasLength(1));
      expect(player.played.single.id, 'song-1');
      expect(player.played.single.platform, 'qq');
      expect(player.played.single.path, '/tmp/first.mp3');
      expect(player.source?.routePath, '/downloads');
      expect(player.source?.queryParameters, {'tab': 'downloaded'});
    },
  );

  testWidgets('available songs can append to the existing queue', (
    tester,
  ) async {
    final player = _Player();
    await tester.pumpWidget(_app(player));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入播放队列'));
    await tester.pumpAndSettle();
    expect(player.appended?.id, 'song-1');
  });

  testWidgets('playback progress does not rebuild downloaded song rows', (
    tester,
  ) async {
    final player = _Player();
    await tester.pumpWidget(_app(player));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('downloaded-song-first'));
    final initial = tester.widget<SongListItem>(row);
    ProviderScope.containerOf(
      tester.element(find.byType(DownloadPage)),
    ).read(playerControllerProvider);
    for (var tick = 1; tick <= 5; tick++) {
      player.tick(tick);
      await tester.pump();
      expect(tester.widget(row), same(initial));
    }
  });

  for (final locale in ['zh', 'en']) {
    testWidgets(
      'downloaded list fits large text on a narrow screen in $locale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_app(_Player(), locale: locale, textScale: 2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _app(
  _Player player, {
  String locale = 'zh',
  double textScale = 1,
  _Tasks? tasks,
}) => ProviderScope(
  overrides: [
    appConfigProvider.overrideWith(() => _Config(locale)),
    playerControllerProvider.overrideWith(() => player),
    downloadedMusicRepositoryProvider.overrideWithValue(_Repository()),
    downloadControllerProvider.overrideWith(() => tasks ?? _Tasks()),
  ],
  child: MaterialApp(
    locale: Locale(locale),
    supportedLocales: const [Locale('zh'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const DownloadPage(),
  ),
);

class _Tasks extends DownloadController {
  DownloadTask? redownloaded;
  @override
  DownloadState build() => DownloadState.initial;
  @override
  Future<void> redownloadSavedSong(DownloadTask saved) async {
    redownloaded = saved;
  }
}

class _Config extends AppConfigController {
  _Config(this.locale);
  final String locale;
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(
    localeCode: locale,
    glassMode: AppGlassMode.off,
  );
}

class _Player extends PlayerController {
  List<PlayerTrack> played = [];
  PlayerTrack? appended;
  PlayerQueueSource? source;
  @override
  PlayerPlaybackState build() => PlayerPlaybackState.initial(const []);
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
    played = queue;
    source = queueSource;
    state = PlayerPlaybackState.initial(
      queue,
    ).copyWith(currentIndex: startIndex);
  }

  @override
  Future<void> appendTrack(PlayerTrack track) async {
    appended = track;
  }

  void tick(int seconds) =>
      state = state.copyWith(position: Duration(seconds: seconds));
}

class _Repository implements DownloadedMusicRepository {
  @override
  Stream<List<DownloadedSong>> watchSongs() => Stream.value([
    _song('first', '夜曲', available: true),
    _song('missing', '失效歌曲', available: false),
  ]);
  @override
  Future<DownloadedSong?> findPlayable({
    required String songId,
    required String platform,
    String? filePath,
  }) async => null;
  @override
  Future<void> remove(String id) async {}
}

DownloadedSong _song(
  String id,
  String title, {
  required bool available,
}) => DownloadedSong(
  isAvailable: available,
  task: DownloadTask.queued(
    id: id,
    title: title,
    url: '',
    songId: 'song-1',
    platform: 'qq',
    artist: available ? '周杰伦' : '其他歌手',
    album: available ? '十一月的萧邦' : '',
  ).copyWith(status: DownloadTaskStatus.completed, filePath: '/tmp/$id.mp3'),
);
