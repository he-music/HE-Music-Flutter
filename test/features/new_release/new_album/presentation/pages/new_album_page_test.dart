import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/new_release/new_album/data/datasources/new_album_api_client.dart';
import 'package:he_music_flutter/features/new_release/new_album/presentation/pages/new_album_page.dart';
import 'package:he_music_flutter/features/new_release/new_album/presentation/providers/new_album_page_providers.dart';
import 'package:he_music_flutter/features/new_release/shared/domain/entities/new_release_page_result.dart';
import 'package:he_music_flutter/features/new_release/shared/domain/entities/new_release_tab.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/plaza_loading_skeleton.dart';

void main() {
  testWidgets('new album page shows all skeleton regions on first load', (
    tester,
  ) async {
    final platformsCompleter = Completer<List<OnlinePlatform>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          newAlbumApiClientProvider.overrideWithValue(_FakeNewAlbumApiClient()),
          onlinePlatformsProvider.overrideWith(
            () => _TestOnlinePlatformsController(platformsCompleter.future),
          ),
        ],
        child: const MaterialApp(home: NewAlbumPage(initialPlatform: 'qq')),
      ),
    );
    await tester.pump();

    expect(find.byType(PlazaPlatformTabsSkeleton), findsOneWidget);
    expect(find.byType(UnderlineTabsSkeleton), findsOneWidget);
    expect(find.byType(PlazaGridSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    platformsCompleter.complete(const <OnlinePlatform>[]);
    await tester.pumpAndSettle();
  });

  testWidgets('new album page renders album grid items', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          newAlbumApiClientProvider.overrideWithValue(_FakeNewAlbumApiClient()),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
        child: const MaterialApp(home: NewAlbumPage(initialPlatform: 'qq')),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('QQ'), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('年度新碟'), findsOneWidget);
  });
}

class _FakeNewAlbumApiClient extends NewAlbumApiClient {
  _FakeNewAlbumApiClient() : super(Dio());

  @override
  Future<List<NewReleaseTab>> fetchTabs({required String platform}) async {
    return <NewReleaseTab>[
      NewReleaseTab(id: 'recommend', name: '推荐', platform: platform),
    ];
  }

  @override
  Future<NewReleasePageResult<AlbumInfo>> fetchAlbums({
    required String platform,
    required String tabId,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    return NewReleasePageResult<AlbumInfo>(
      list: <AlbumInfo>[_buildAlbum(platform)],
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
                PlatformFeatureSupportFlag.getNewAlbumTabList |
                PlatformFeatureSupportFlag.getNewAlbumList,
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

AlbumInfo _buildAlbum(String platform) {
  return AlbumInfo(
    name: '年度新碟',
    id: 'album-1',
    cover: '',
    artists: const <SongInfoArtistInfo>[
      SongInfoArtistInfo(id: 'artist-1', name: '歌手'),
    ],
    songCount: '10',
    publishTime: '2026-04-15',
    songs: const <SongInfo>[],
    description: '',
    platform: platform,
    language: '',
    genre: '',
    type: 0,
    isFinished: true,
    playCount: '100',
  );
}
