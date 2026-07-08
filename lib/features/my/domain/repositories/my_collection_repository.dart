import '../entities/my_favorite_item.dart';
import '../entities/my_favorite_type.dart';

abstract interface class MyCollectionRepository {
  Future<List<MyFavoriteItem>> fetchFavorites(MyFavoriteType type);

  Future<void> removeFavorite({
    required MyFavoriteType type,
    required String id,
    required String platform,
  });
}
