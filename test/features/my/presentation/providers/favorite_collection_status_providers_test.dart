import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/my/data/datasources/my_collection_api_client.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_collection_status_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_collection_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/utils/id_platform_key.dart';

void main() {
  test('build 不自动发起收藏状态网络刷新', () async {
    final client = _ControlledMyCollectionApiClient();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_SignedInAppConfigController.new),
        myCollectionApiClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(favoriteCollectionStatusProvider);
    await Future<void>.delayed(Duration.zero);

    expect(state.ready, isFalse);
    expect(client.startedTypes, isEmpty);
  });

  test('refresh 并行拉取歌单歌手专辑并写入 key 集合', () async {
    final client = _ControlledMyCollectionApiClient();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_SignedInAppConfigController.new),
        myCollectionApiClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    final refresh = container
        .read(favoriteCollectionStatusProvider.notifier)
        .refresh();
    await Future<void>.delayed(Duration.zero);

    expect(
      client.startedTypes,
      unorderedEquals(<MyFavoriteType>[
        MyFavoriteType.playlists,
        MyFavoriteType.artists,
        MyFavoriteType.albums,
      ]),
    );

    client.complete(MyFavoriteType.playlists, const <IdPlatformInfo>[
      IdPlatformInfo(id: 'playlist-1', platform: 'qq'),
    ]);
    client.complete(MyFavoriteType.artists, const <IdPlatformInfo>[
      IdPlatformInfo(id: 'artist-1', platform: 'qq'),
    ]);
    client.complete(MyFavoriteType.albums, const <IdPlatformInfo>[
      IdPlatformInfo(id: 'album-1', platform: 'qq'),
    ]);
    await refresh;

    final state = container.read(favoriteCollectionStatusProvider);
    expect(state.ready, isTrue);
    expect(
      state.playlistKeys,
      contains(buildIdPlatformKey(id: 'playlist-1', platform: 'qq')),
    );
    expect(
      state.artistKeys,
      contains(buildIdPlatformKey(id: 'artist-1', platform: 'qq')),
    );
    expect(
      state.albumKeys,
      contains(buildIdPlatformKey(id: 'album-1', platform: 'qq')),
    );
  });

  test('并发 refresh 复用同一轮请求', () async {
    final client = _ControlledMyCollectionApiClient();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_SignedInAppConfigController.new),
        myCollectionApiClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    final firstRefresh = container
        .read(favoriteCollectionStatusProvider.notifier)
        .refresh();
    final secondRefresh = container
        .read(favoriteCollectionStatusProvider.notifier)
        .refresh();
    await Future<void>.delayed(Duration.zero);

    expect(client.startedTypes.length, 3);

    client.completeAll();
    await Future.wait<void>(<Future<void>>[firstRefresh, secondRefresh]);

    expect(container.read(favoriteCollectionStatusProvider).ready, isTrue);
  });
}

class _SignedInAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(authToken: 'token');
  }
}

class _ControlledMyCollectionApiClient extends MyCollectionApiClient {
  _ControlledMyCollectionApiClient() : super(Dio());

  final List<MyFavoriteType> startedTypes = <MyFavoriteType>[];
  final Map<MyFavoriteType, Completer<List<IdPlatformInfo>>> _completers =
      <MyFavoriteType, Completer<List<IdPlatformInfo>>>{
        MyFavoriteType.playlists: Completer<List<IdPlatformInfo>>(),
        MyFavoriteType.artists: Completer<List<IdPlatformInfo>>(),
        MyFavoriteType.albums: Completer<List<IdPlatformInfo>>(),
      };

  @override
  Future<List<IdPlatformInfo>> fetchFavoriteIdPlatforms(MyFavoriteType type) {
    startedTypes.add(type);
    return _completers[type]!.future;
  }

  void complete(MyFavoriteType type, List<IdPlatformInfo> items) {
    _completers[type]!.complete(items);
  }

  void completeAll() {
    for (final entry in _completers.entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete(const <IdPlatformInfo>[]);
      }
    }
  }
}
