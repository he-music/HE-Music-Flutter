import '../../../../shared/models/he_music_models.dart';

class PlaylistCategoryGroup {
  const PlaylistCategoryGroup({required this.name, required this.categories});

  final String name;
  final List<CategoryInfo> categories;

  factory PlaylistCategoryGroup.fromMap(
    Map<String, dynamic> raw, {
    required String platform,
  }) {
    final categoriesRaw = raw['categories'];
    final categories = categoriesRaw is List
        ? categoriesRaw
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return CategoryInfo.fromMap(item, fallbackPlatform: platform);
                }
                if (item is Map) {
                  return CategoryInfo.fromMap(
                    item.map((key, value) => MapEntry('$key', value)),
                    fallbackPlatform: platform,
                  );
                }
                return CategoryInfo(
                  name: '$item'.trim(),
                  id: '',
                  platform: platform,
                );
              })
              .where((item) => item.name.trim().isNotEmpty)
              .toList(growable: false)
        : const <CategoryInfo>[];
    return PlaylistCategoryGroup(
      name: '${raw['name'] ?? ''}'.trim(),
      categories: categories,
    );
  }
}
