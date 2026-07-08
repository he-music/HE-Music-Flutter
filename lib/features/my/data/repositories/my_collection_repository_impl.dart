import '../../domain/entities/my_favorite_item.dart';
import '../../domain/entities/my_favorite_type.dart';
import '../../domain/repositories/my_collection_repository.dart';
import '../datasources/my_collection_api_client.dart';

class MyCollectionRepositoryImpl implements MyCollectionRepository {
  const MyCollectionRepositoryImpl(this._apiClient);

  final MyCollectionApiClient _apiClient;

  @override
  Future<List<MyFavoriteItem>> fetchFavorites(MyFavoriteType type) {
    return _apiClient.fetchFavorites(type);
  }

  @override
  Future<void> removeFavorite({
    required MyFavoriteType type,
    required String id,
    required String platform,
  }) {
    return _apiClient.removeFavorite(type: type, id: id, platform: platform);
  }
}
