import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/my_favorite_item.dart';
import '../../domain/entities/my_favorite_type.dart';
import 'my_collection_providers.dart';

final myCreatedPlaylistsProvider = FutureProvider<List<MyFavoriteItem>>((
  ref,
) async {
  final apiClient = ref.watch(myCollectionApiClientProvider);
  return apiClient.fetchCreatedPlaylists();
});

final myFavoritePlaylistsProvider = FutureProvider<List<MyFavoriteItem>>((
  ref,
) async {
  final apiClient = ref.watch(myCollectionApiClientProvider);
  return apiClient.fetchFavorites(MyFavoriteType.playlists);
});
