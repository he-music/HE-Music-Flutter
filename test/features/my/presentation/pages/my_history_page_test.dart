import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
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
  });
}

Widget _buildTestApp({required List<PlayerHistoryItem> items}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      myHistoryControllerProvider.overrideWith(
        () => _TestMyHistoryController(items: items),
      ),
      favoriteSongStatusProvider.overrideWith(
        _TestFavoriteSongStatusController.new,
      ),
      onlinePlatformsProvider.overrideWith(_TestOnlinePlatformsController.new),
      playerControllerProvider.overrideWith(_TestPlayerController.new),
    ],
    child: MaterialApp(
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
}

class _TestMyHistoryController extends MyHistoryController {
  _TestMyHistoryController({required this.items});

  final List<PlayerHistoryItem> items;

  @override
  Future<List<PlayerHistoryItem>> build() async => items;
}

class _TestFavoriteSongStatusController extends FavoriteSongStatusController {
  @override
  FavoriteSongStatusState build() {
    return const FavoriteSongStatusState(songKeys: <String>{}, ready: true);
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.getCommentList,
      ),
    ];
  }
}

class _TestPlayerController extends PlayerController {
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
}
