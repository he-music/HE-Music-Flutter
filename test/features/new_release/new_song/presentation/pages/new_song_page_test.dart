import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/new_release/new_song/data/datasources/new_song_api_client.dart';
import 'package:he_music_flutter/features/new_release/new_song/presentation/pages/new_song_page.dart';
import 'package:he_music_flutter/features/new_release/new_song/presentation/providers/new_song_page_providers.dart';
import 'package:he_music_flutter/features/new_release/shared/domain/entities/new_release_page_result.dart';
import 'package:he_music_flutter/features/new_release/shared/domain/entities/new_release_tab.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_song_status_state.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_feature_state.dart';
import 'package:he_music_flutter/features/online/presentation/controllers/online_controller.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_quality_option.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_source.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/online_song_list_item.dart';
import 'package:he_music_flutter/shared/widgets/plaza_loading_skeleton.dart';
import 'package:he_music_flutter/shared/widgets/song_list_component.dart';

void main() {
  testWidgets('new song page shows all skeleton regions on first load', (
    tester,
  ) async {
    final platformsCompleter = Completer<List<OnlinePlatform>>();

    await tester.pumpWidget(
      _buildTestApp(platformsFuture: platformsCompleter.future),
    );
    await tester.pump();

    expect(find.byType(PlazaPlatformTabsSkeleton), findsOneWidget);
    expect(find.byType(UnderlineTabsSkeleton), findsOneWidget);
    expect(
      tester
          .widget<SongListComponent>(find.byType(SongListComponent))
          .initialLoading,
      isTrue,
    );
    expect(find.text('暂无新歌'), findsNothing);

    platformsCompleter.complete(const <OnlinePlatform>[]);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'new song page shows english title and empty text for en locale',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          localeCode: 'en',
          apiClient: _FakeEmptyNewSongApiClient(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('New Songs'), findsOneWidget);
      expect(find.text('No new songs'), findsOneWidget);
    },
  );

  testWidgets('new song page renders platform tabs and category tabs', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());

    await tester.pumpAndSettle();

    expect(find.text('QQ'), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('今日新歌'), findsOneWidget);
  });

  testWidgets('tap song plays current new song list', (tester) async {
    final playerController = _TestPlayerController();

    await tester.pumpWidget(_buildTestApp(playerController: playerController));
    await tester.pumpAndSettle();

    await tester.tap(find.text('今日新歌'));
    await tester.pumpAndSettle();

    expect(playerController.lastReplacedQueue, hasLength(1));
    expect(playerController.lastReplacedQueue.single.id, 'song-1');
    expect(playerController.state.currentTrack?.id, 'song-1');
  });

  testWidgets('tap like toggles favorite through online controller', (
    tester,
  ) async {
    final onlineController = _TestOnlineController();

    await tester.pumpWidget(_buildTestApp(onlineController: onlineController));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Like'));
    await tester.pumpAndSettle();

    expect(onlineController.toggleCalls, hasLength(1));
    expect(
      onlineController.toggleCalls.single,
      const _FavoriteToggleCall(songId: 'song-1', platform: 'qq', like: true),
    );
  });

  testWidgets('new song item wires more action', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    final item = tester.widget<OnlineSongListItem>(
      find.byType(OnlineSongListItem),
    );

    expect(item.onMoreTap, isNotNull);
  });
}

Widget _buildTestApp({
  _TestPlayerController? playerController,
  _TestOnlineController? onlineController,
  NewSongApiClient? apiClient,
  String localeCode = 'zh',
  Future<List<OnlinePlatform>>? platformsFuture,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(localeCode: localeCode),
      ),
      playerControllerProvider.overrideWith(
        () => playerController ?? _TestPlayerController(),
      ),
      onlineControllerProvider.overrideWith(
        () => onlineController ?? _TestOnlineController(),
      ),
      favoriteSongStatusProvider.overrideWith(
        _TestFavoriteSongStatusController.new,
      ),
      newSongApiClientProvider.overrideWithValue(
        apiClient ?? _FakeNewSongApiClient(),
      ),
      onlinePlatformsProvider.overrideWith(
        () => _TestOnlinePlatformsController(platformsFuture),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: const NewSongPage(initialPlatform: 'qq'),
    ),
  );
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({required this.localeCode});

  final String localeCode;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: localeCode,
      apiBaseUrl: 'https://example.com',
      authToken: 'token',
    );
  }
}

class _FakeNewSongApiClient extends NewSongApiClient {
  _FakeNewSongApiClient() : super(Dio());

  @override
  Future<List<NewReleaseTab>> fetchTabs({required String platform}) async {
    return <NewReleaseTab>[
      NewReleaseTab(id: 'recommend', name: '推荐', platform: platform),
    ];
  }

  @override
  Future<NewReleasePageResult<SongInfo>> fetchSongs({
    required String platform,
    required String tabId,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    return NewReleasePageResult<SongInfo>(
      list: <SongInfo>[_buildSong(platform)],
      hasMore: false,
    );
  }
}

class _FakeEmptyNewSongApiClient extends _FakeNewSongApiClient {
  @override
  Future<NewReleasePageResult<SongInfo>> fetchSongs({
    required String platform,
    required String tabId,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    return NewReleasePageResult<SongInfo>(
      list: const <SongInfo>[],
      hasMore: false,
    );
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  _TestOnlinePlatformsController([this.platformsFuture]);

  final Future<List<OnlinePlatform>>? platformsFuture;

  @override
  Future<List<OnlinePlatform>> build() async {
    return platformsFuture ??
        <OnlinePlatform>[
          OnlinePlatform(
            id: 'qq',
            name: 'QQ Music',
            shortName: 'QQ',
            status: 1,
            featureSupportFlag:
                PlatformFeatureSupportFlag.getNewSongTabList |
                PlatformFeatureSupportFlag.getNewSongList |
                PlatformFeatureSupportFlag.getCommentList,
          ),
        ];
  }
}

class _TestPlayerController extends PlayerController {
  List<PlayerTrack> lastReplacedQueue = const <PlayerTrack>[];

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
    lastReplacedQueue = List<PlayerTrack>.from(queue);
    state = state.copyWith(
      queue: lastReplacedQueue,
      currentIndex: startIndex,
      currentAvailableQualities: const <PlayerQualityOption>[],
    );
  }

  @override
  Future<void> insertNextTrack(PlayerTrack track) async {}

  @override
  Future<void> appendTrack(PlayerTrack track) async {}

  @override
  Future<void> insertNextAndPlay(PlayerTrack track) async {}
}

class _TestOnlineController extends OnlineController {
  final List<_FavoriteToggleCall> toggleCalls = <_FavoriteToggleCall>[];

  @override
  OnlineFeatureState build() {
    return OnlineFeatureState.initial;
  }

  @override
  Future<void> toggleSongFavorite({
    required String songId,
    required String platform,
    required bool like,
  }) async {
    toggleCalls.add(
      _FavoriteToggleCall(songId: songId, platform: platform, like: like),
    );
    final status = ref.read(favoriteSongStatusProvider.notifier);
    if (like) {
      status.addSong(songId: songId, platform: platform);
    } else {
      status.removeSong(songId: songId, platform: platform);
    }
  }
}

class _TestFavoriteSongStatusController extends FavoriteSongStatusController {
  @override
  FavoriteSongStatusState build() {
    return const FavoriteSongStatusState(songKeys: <String>{}, ready: true);
  }
}

class _FavoriteToggleCall {
  const _FavoriteToggleCall({
    required this.songId,
    required this.platform,
    required this.like,
  });

  final String songId;
  final String platform;
  final bool like;

  @override
  bool operator ==(Object other) {
    return other is _FavoriteToggleCall &&
        other.songId == songId &&
        other.platform == platform &&
        other.like == like;
  }

  @override
  int get hashCode => Object.hash(songId, platform, like);
}

SongInfo _buildSong(String platform) {
  return SongInfo(
    name: '今日新歌',
    subtitle: '',
    id: 'song-1',
    duration: 180000,
    mvId: '',
    album: const SongInfoAlbumInfo(id: 'album-1', name: '专辑'),
    artists: const <SongInfoArtistInfo>[
      SongInfoArtistInfo(id: 'artist-1', name: '歌手'),
    ],
    links: const <LinkInfo>[],
    platform: platform,
    cover: '',
  );
}
