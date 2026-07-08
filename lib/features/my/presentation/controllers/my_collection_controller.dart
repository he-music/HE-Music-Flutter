import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/my_collection_state.dart';
import '../../domain/entities/my_favorite_item.dart';
import '../../domain/entities/my_favorite_type.dart';
import '../../domain/repositories/my_collection_repository.dart';
import '../providers/favorite_collection_status_providers.dart';
import '../providers/my_collection_providers.dart';
import '../providers/my_overview_providers.dart';

class MyCollectionController extends Notifier<MyCollectionState> {
  bool _initialized = false;

  @override
  MyCollectionState build() {
    return MyCollectionState.initial;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await refreshAll();
    _initialized = true;
  }

  void selectType(MyFavoriteType type) {
    if (state.selectedType == type) {
      return;
    }
    state = state.copyWith(selectedType: type, clearError: true);
  }

  Future<void> refreshAll() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final playlists = await _repository.fetchFavorites(
        MyFavoriteType.playlists,
      );
      final artists = await _repository.fetchFavorites(MyFavoriteType.artists);
      final albums = await _repository.fetchFavorites(MyFavoriteType.albums);
      state = state.copyWith(
        loading: false,
        playlists: playlists,
        artists: artists,
        albums: albums,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(loading: false, errorMessage: '$error');
    }
  }

  Future<void> removeFavorite(MyFavoriteItem item) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _repository.removeFavorite(
        type: item.type,
        id: item.id,
        platform: item.platform,
      );
      ref
          .read(favoriteCollectionStatusProvider.notifier)
          .remove(type: item.type, id: item.id, platform: item.platform);
      await _refreshType(item.type);
      await ref.read(myOverviewControllerProvider.notifier).refresh();
      state = state.copyWith(loading: false, clearError: true);
    } catch (error) {
      state = state.copyWith(loading: false, errorMessage: '$error');
    }
  }

  Future<void> _refreshType(MyFavoriteType type) async {
    final items = await _repository.fetchFavorites(type);
    state = switch (type) {
      MyFavoriteType.songs => state,
      MyFavoriteType.playlists => state.copyWith(playlists: items),
      MyFavoriteType.artists => state.copyWith(artists: items),
      MyFavoriteType.albums => state.copyWith(albums: items),
    };
  }

  MyCollectionRepository get _repository {
    return ref.read(myCollectionRepositoryProvider);
  }
}
