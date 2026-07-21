import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/new_release/new_album/data/datasources/new_album_api_client.dart';
import 'package:he_music_flutter/features/new_release/new_album/presentation/providers/new_album_page_providers.dart';
import 'package:he_music_flutter/features/new_release/shared/domain/entities/new_release_page_result.dart';
import 'package:he_music_flutter/features/new_release/shared/domain/entities/new_release_tab.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test(
    'initialize falls back to first supported platform when routed platform unsupported',
    () async {
      final client = _FakeNewAlbumApiClient();
      final container = ProviderContainer(
        overrides: [
          newAlbumApiClientProvider.overrideWithValue(client),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(newAlbumPageControllerProvider.notifier)
          .initialize(preferredPlatformId: 'wy', preferredTabId: 'latest');

      final state = container.read(newAlbumPageControllerProvider);
      expect(state.platforms.map((item) => item.id), <String>['qq', 'kg']);
      expect(state.selectedPlatformId, 'qq');
      expect(state.selectedTabId, 'latest');
      expect(state.albums.map((item) => item.name), <String>['qq-latest-1']);
      expect(client.fetchTabsCalls, <String>['qq']);
      expect(client.fetchAlbumsCalls, <String>['qq|latest|1']);
    },
  );

  test('selectTab resets albums and restarts paging from first page', () async {
    final client = _FakeNewAlbumApiClient();
    final container = ProviderContainer(
      overrides: [
        newAlbumApiClientProvider.overrideWithValue(client),
        onlinePlatformsProvider.overrideWith(
          _TestOnlinePlatformsController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(newAlbumPageControllerProvider.notifier);
    await controller.initialize(preferredPlatformId: 'qq');
    await controller.loadMore();
    await controller.selectTab('latest');

    final state = container.read(newAlbumPageControllerProvider);
    expect(state.selectedTabId, 'latest');
    expect(state.albums.map((item) => item.name), <String>['qq-latest-1']);
    expect(state.pageIndex, 2);
    expect(client.fetchAlbumsCalls, <String>[
      'qq|recommend|1',
      'qq|recommend|2',
      'qq|latest|1',
    ]);
  });

  test('selectPlatform clears the previous tab while new tabs load', () async {
    final client = _FakeNewAlbumApiClient();
    final container = ProviderContainer(
      overrides: [
        newAlbumApiClientProvider.overrideWithValue(client),
        onlinePlatformsProvider.overrideWith(
          _TestOnlinePlatformsController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(newAlbumPageControllerProvider.notifier);
    await controller.initialize(preferredPlatformId: 'qq');
    final tabsCompleter = Completer<List<NewReleaseTab>>();
    client.delayedTabs = tabsCompleter;

    final selection = controller.selectPlatform('kg');
    final loadingState = container.read(newAlbumPageControllerProvider);
    expect(loadingState.selectedPlatformId, 'kg');
    expect(loadingState.selectedTabId, isNull);
    expect(loadingState.tabs, isEmpty);
    expect(loadingState.albums, isEmpty);
    expect(loadingState.tabsLoading, isTrue);
    expect(loadingState.albumsLoading, isTrue);

    tabsCompleter.complete(<NewReleaseTab>[
      const NewReleaseTab(id: 'recommend', name: '推荐', platform: 'kg'),
    ]);
    await selection;
  });
}

class _FakeNewAlbumApiClient extends NewAlbumApiClient {
  _FakeNewAlbumApiClient() : super(Dio());

  final List<String> fetchTabsCalls = <String>[];
  final List<String> fetchAlbumsCalls = <String>[];
  Completer<List<NewReleaseTab>>? delayedTabs;

  @override
  Future<List<NewReleaseTab>> fetchTabs({required String platform}) async {
    fetchTabsCalls.add(platform);
    if (platform == 'kg' && delayedTabs != null) {
      return delayedTabs!.future;
    }
    return <NewReleaseTab>[
      NewReleaseTab(id: 'recommend', name: '推荐', platform: platform),
      NewReleaseTab(id: 'latest', name: '最新', platform: platform),
    ];
  }

  @override
  Future<NewReleasePageResult<AlbumInfo>> fetchAlbums({
    required String platform,
    required String tabId,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    fetchAlbumsCalls.add('$platform|$tabId|$pageIndex');
    final suffix = pageIndex == 1 ? '1' : '2';
    return NewReleasePageResult<AlbumInfo>(
      list: <AlbumInfo>[
        _buildAlbum(platform: platform, tabId: tabId, suffix: suffix),
      ],
      hasMore: pageIndex == 1,
    );
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    final newAlbumFlags =
        PlatformFeatureSupportFlag.getNewAlbumTabList |
        PlatformFeatureSupportFlag.getNewAlbumList;
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ Music',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: newAlbumFlags,
      ),
      OnlinePlatform(
        id: 'kg',
        name: 'KuGou',
        shortName: 'KG',
        status: 1,
        featureSupportFlag: newAlbumFlags,
      ),
      OnlinePlatform(
        id: 'wy',
        name: 'WangYi',
        shortName: 'WY',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.getNewAlbumTabList,
      ),
    ];
  }
}

AlbumInfo _buildAlbum({
  required String platform,
  required String tabId,
  required String suffix,
}) {
  return AlbumInfo(
    name: '$platform-$tabId-$suffix',
    id: '$platform-$tabId-$suffix',
    cover: '',
    artists: const <SongInfoArtistInfo>[
      SongInfoArtistInfo(id: 'artist-1', name: 'Artist'),
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
