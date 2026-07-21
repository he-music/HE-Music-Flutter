import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/new_release/new_song/data/datasources/new_song_api_client.dart';
import 'package:he_music_flutter/features/new_release/new_song/presentation/providers/new_song_page_providers.dart';
import 'package:he_music_flutter/features/new_release/shared/domain/entities/new_release_page_result.dart';
import 'package:he_music_flutter/features/new_release/shared/domain/entities/new_release_tab.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test(
    'initialize prefers routed platform when capability filter passes',
    () async {
      final client = _FakeNewSongApiClient();
      final container = ProviderContainer(
        overrides: [
          newSongApiClientProvider.overrideWithValue(client),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(newSongPageControllerProvider.notifier)
          .initialize(preferredPlatformId: 'kg', preferredTabId: 'latest');

      final state = container.read(newSongPageControllerProvider);
      expect(state.platforms.map((item) => item.id), <String>['qq', 'kg']);
      expect(state.selectedPlatformId, 'kg');
      expect(state.selectedTabId, 'latest');
      expect(state.songs.map((item) => item.name), <String>['kg-latest-1']);
      expect(client.fetchTabsCalls, <String>['kg']);
      expect(client.fetchSongsCalls, <String>['kg|latest|1']);
    },
  );

  test('loadMore appends songs from next page', () async {
    final client = _FakeNewSongApiClient();
    final container = ProviderContainer(
      overrides: [
        newSongApiClientProvider.overrideWithValue(client),
        onlinePlatformsProvider.overrideWith(
          _TestOnlinePlatformsController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(newSongPageControllerProvider.notifier)
        .initialize(preferredPlatformId: 'qq');
    await container.read(newSongPageControllerProvider.notifier).loadMore();

    final state = container.read(newSongPageControllerProvider);
    expect(state.songs.map((item) => item.name), <String>[
      'qq-recommend-1',
      'qq-recommend-2',
    ]);
    expect(state.pageIndex, 3);
    expect(state.hasMore, false);
    expect(client.fetchSongsCalls, <String>[
      'qq|recommend|1',
      'qq|recommend|2',
    ]);
  });

  test(
    'switching back to previous platform refetches instead of using cache',
    () async {
      final client = _FakeNewSongApiClient();
      final container = ProviderContainer(
        overrides: [
          newSongApiClientProvider.overrideWithValue(client),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(newSongPageControllerProvider.notifier);
      await controller.initialize(preferredPlatformId: 'qq');
      await controller.selectPlatform('kg');
      await controller.selectPlatform('qq');

      final state = container.read(newSongPageControllerProvider);
      expect(state.selectedPlatformId, 'qq');
      expect(state.songs.map((item) => item.name), <String>['qq-recommend-1']);
      expect(client.fetchTabsCalls, <String>['qq', 'kg', 'qq']);
      expect(client.fetchSongsCalls, <String>[
        'qq|recommend|1',
        'kg|recommend|1',
        'qq|recommend|1',
      ]);
    },
  );

  test('selectPlatform clears the previous tab while new tabs load', () async {
    final client = _FakeNewSongApiClient();
    final container = ProviderContainer(
      overrides: [
        newSongApiClientProvider.overrideWithValue(client),
        onlinePlatformsProvider.overrideWith(
          _TestOnlinePlatformsController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(newSongPageControllerProvider.notifier);
    await controller.initialize(preferredPlatformId: 'qq');
    final tabsCompleter = Completer<List<NewReleaseTab>>();
    client.delayedTabs = tabsCompleter;

    final selection = controller.selectPlatform('kg');
    final loadingState = container.read(newSongPageControllerProvider);
    expect(loadingState.selectedPlatformId, 'kg');
    expect(loadingState.selectedTabId, isNull);
    expect(loadingState.tabs, isEmpty);
    expect(loadingState.songs, isEmpty);
    expect(loadingState.tabsLoading, isTrue);
    expect(loadingState.songsLoading, isTrue);

    tabsCompleter.complete(<NewReleaseTab>[
      const NewReleaseTab(id: 'recommend', name: '推荐', platform: 'kg'),
    ]);
    await selection;
  });
}

class _FakeNewSongApiClient extends NewSongApiClient {
  _FakeNewSongApiClient() : super(Dio());

  final List<String> fetchTabsCalls = <String>[];
  final List<String> fetchSongsCalls = <String>[];
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
  Future<NewReleasePageResult<SongInfo>> fetchSongs({
    required String platform,
    required String tabId,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    fetchSongsCalls.add('$platform|$tabId|$pageIndex');
    final suffix = pageIndex == 1 ? '1' : '2';
    return NewReleasePageResult<SongInfo>(
      list: <SongInfo>[
        _buildSong(platform: platform, tabId: tabId, suffix: suffix),
      ],
      hasMore: pageIndex == 1,
    );
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    final newSongFlags =
        PlatformFeatureSupportFlag.getNewSongTabList |
        PlatformFeatureSupportFlag.getNewSongList;
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ Music',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: newSongFlags,
      ),
      OnlinePlatform(
        id: 'kg',
        name: 'KuGou',
        shortName: 'KG',
        status: 1,
        featureSupportFlag: newSongFlags,
      ),
      OnlinePlatform(
        id: 'wy',
        name: 'WangYi',
        shortName: 'WY',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.getNewSongTabList,
      ),
    ];
  }
}

SongInfo _buildSong({
  required String platform,
  required String tabId,
  required String suffix,
}) {
  return SongInfo(
    name: '$platform-$tabId-$suffix',
    subtitle: '',
    id: '$platform-$tabId-$suffix',
    duration: 180000,
    mvId: '',
    album: SongInfoAlbumInfo(id: 'album-1', name: 'Album'),
    artists: const <SongInfoArtistInfo>[
      SongInfoArtistInfo(id: 'artist-1', name: 'Artist'),
    ],
    links: const <LinkInfo>[],
    platform: platform,
    cover: '',
    sublist: const <SongInfo>[],
    originalType: 0,
  );
}
