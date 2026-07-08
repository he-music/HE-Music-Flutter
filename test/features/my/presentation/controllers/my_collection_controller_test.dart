import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_overview_state.dart';
import 'package:he_music_flutter/features/my/domain/repositories/my_collection_repository.dart';
import 'package:he_music_flutter/features/my/presentation/controllers/my_overview_controller.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_collection_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_overview_providers.dart';

void main() {
  test('initialize should load all favorite types', () async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        myOverviewControllerProvider.overrideWith(
          _TestMyOverviewController.new,
        ),
        myCollectionRepositoryProvider.overrideWithValue(
          _FakeMyCollectionRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(myCollectionControllerProvider.notifier).initialize();
    final state = container.read(myCollectionControllerProvider);

    expect(state.loading, false);
    expect(state.errorMessage, isNull);
    expect(state.playlists.length, 1);
    expect(state.artists.length, 1);
    expect(state.albums.length, 1);
    expect(state.selectedType, MyFavoriteType.playlists);
    expect(state.selectedItems.length, 1);
  });

  test('selectType should expose empty items for songs tab', () async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        myOverviewControllerProvider.overrideWith(
          _TestMyOverviewController.new,
        ),
        myCollectionRepositoryProvider.overrideWithValue(
          _FakeMyCollectionRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(myCollectionControllerProvider.notifier).refreshAll();
    container
        .read(myCollectionControllerProvider.notifier)
        .selectType(MyFavoriteType.songs);
    final state = container.read(myCollectionControllerProvider);

    expect(state.selectedType, MyFavoriteType.songs);
    expect(state.selectedItems, isEmpty);
  });

  test('removeFavorite should remove playlist from selected list', () async {
    final repository = _FakeMyCollectionRepository();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        myOverviewControllerProvider.overrideWith(
          _TestMyOverviewController.new,
        ),
        myCollectionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(myCollectionControllerProvider.notifier).refreshAll();
    final firstPlaylist = container
        .read(myCollectionControllerProvider)
        .playlists
        .first;

    await container
        .read(myCollectionControllerProvider.notifier)
        .removeFavorite(firstPlaylist);
    final state = container.read(myCollectionControllerProvider);

    expect(state.playlists.length, 0);
    expect(state.selectedItems, isEmpty);
  });
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial;
  }
}

class _TestMyOverviewController extends MyOverviewController {
  @override
  MyOverviewState build() {
    return MyOverviewState.initial;
  }

  @override
  Future<void> refresh() async {}
}

class _FakeMyCollectionRepository implements MyCollectionRepository {
  final Map<MyFavoriteType, List<MyFavoriteItem>> _itemsByType =
      <MyFavoriteType, List<MyFavoriteItem>>{
        MyFavoriteType.playlists: <MyFavoriteItem>[
          const MyFavoriteItem(
            id: 'playlist-1',
            platform: 'kuwo',
            type: MyFavoriteType.playlists,
            title: 'Playlist',
            subtitle: 'kuwo',
            coverUrl: '',
          ),
        ],
        MyFavoriteType.songs: <MyFavoriteItem>[],
        MyFavoriteType.artists: <MyFavoriteItem>[
          const MyFavoriteItem(
            id: 'artist-1',
            platform: 'kuwo',
            type: MyFavoriteType.artists,
            title: 'Artist',
            subtitle: 'kuwo',
            coverUrl: '',
          ),
        ],
        MyFavoriteType.albums: <MyFavoriteItem>[
          const MyFavoriteItem(
            id: 'album-1',
            platform: 'kuwo',
            type: MyFavoriteType.albums,
            title: 'Album',
            subtitle: 'kuwo',
            coverUrl: '',
          ),
        ],
      };

  @override
  Future<List<MyFavoriteItem>> fetchFavorites(MyFavoriteType type) async {
    return _itemsByType[type]!.toList(growable: false);
  }

  @override
  Future<void> removeFavorite({
    required MyFavoriteType type,
    required String id,
    required String platform,
  }) async {
    final list = _itemsByType[type]!;
    list.removeWhere((item) => item.id == id && item.platform == platform);
  }
}
