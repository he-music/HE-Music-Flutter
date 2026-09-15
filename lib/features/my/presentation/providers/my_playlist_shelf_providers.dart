import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../domain/entities/my_favorite_item.dart';
import 'my_collection_providers.dart';

final myCreatedPlaylistsProvider = FutureProvider<List<MyFavoriteItem>>((
  ref,
) async {
  final token = ref.watch(
    appConfigProvider.select((config) => config.authToken?.trim() ?? ''),
  );
  if (token.isEmpty) {
    return const <MyFavoriteItem>[];
  }
  final apiClient = ref.watch(myCollectionApiClientProvider);
  return apiClient.fetchCreatedPlaylists();
});

// 收藏歌单由收藏控制器统一持有；此 provider 只为歌单架提供展示状态。
final myFavoritePlaylistsProvider = Provider<AsyncValue<List<MyFavoriteItem>>>((
  ref,
) {
  final token = ref.watch(
    appConfigProvider.select((config) => config.authToken?.trim() ?? ''),
  );
  if (token.isEmpty) {
    return const AsyncData(<MyFavoriteItem>[]);
  }
  final (loading, error, playlists) = ref.watch(
    myCollectionControllerProvider.select(
      (state) => (state.loading, state.errorMessage, state.playlists),
    ),
  );
  Future.microtask(() {
    if (ref.mounted) {
      ref.read(myCollectionControllerProvider.notifier).initialize();
    }
  });
  if (playlists.isNotEmpty) {
    return AsyncData(playlists);
  }
  if (loading) {
    return const AsyncLoading();
  }
  if (error != null) {
    return AsyncError(error, StackTrace.current);
  }
  return AsyncData(playlists);
});
