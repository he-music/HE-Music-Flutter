import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/artist_photo_providers.dart';

export '../../data/providers/artist_photo_providers.dart';

/// 歌手写真缓存管理 provider。
///
/// 以 `platform + sorted ids + sorted names` 作为缓存键，
/// 同一首歌反复进入播放页不会重复请求。
final artistPhotoCacheProvider =
    NotifierProvider<ArtistPhotoCache, ArtistPhotoCacheState>(
      ArtistPhotoCache.new,
    );

class ArtistPhotoCacheState {
  const ArtistPhotoCacheState({
    this.cache = const <String, ArtistPhotoCacheEntry>{},
    this.currentIndices = const <String, int>{},
  });

  /// 缓存映射：cacheKey -> entry。
  final Map<String, ArtistPhotoCacheEntry> cache;

  /// 当前轮播索引映射：cacheKey -> index，跨页面保持写真位置。
  final Map<String, int> currentIndices;
}

class ArtistPhotoCacheEntry {
  const ArtistPhotoCacheEntry({required this.urls, required this.cachedAt});

  final List<String> urls;
  final DateTime cachedAt;
}

class ArtistPhotoCache extends Notifier<ArtistPhotoCacheState> {
  /// 缓存有效期，超过此时间会重新请求。
  static const Duration _ttl = Duration(hours: 2);

  @override
  ArtistPhotoCacheState build() {
    return const ArtistPhotoCacheState();
  }

  /// 根据歌曲信息获取歌手写真 URL 列表。
  ///
  /// 优先从缓存读取；缓存未命中或已过期时发起网络请求。
  Future<List<String>> fetchPhotos({
    required String platform,
    List<String> ids = const <String>[],
    List<String> names = const <String>[],
    bool isPortrait = false,
  }) async {
    final key = buildCacheKey(platform, ids, names, isPortrait);
    final cached = state.cache[key];
    if (cached != null && !_isExpired(cached)) {
      return cached.urls;
    }

    final apiClient = ref.read(artistPhotoApiClientProvider);
    final urls = await apiClient.listPhotos(
      platform: platform,
      ids: ids,
      names: names,
      isPortrait: isPortrait,
    );

    state = ArtistPhotoCacheState(
      cache: <String, ArtistPhotoCacheEntry>{
        ...state.cache,
        key: ArtistPhotoCacheEntry(urls: urls, cachedAt: DateTime.now()),
      },
    );
    return urls;
  }

  /// 获取指定歌手的当前轮播索引，默认 0。
  int currentIndex(String cacheKey) {
    return state.currentIndices[cacheKey] ?? 0;
  }

  /// 更新指定歌手的轮播索引。
  void updateIndex(String cacheKey, int index) {
    state = ArtistPhotoCacheState(
      cache: state.cache,
      currentIndices: <String, int>{
        ...state.currentIndices,
        cacheKey: index,
      },
    );
  }

  /// 构建缓存键：platform + ids 升序拼接 + names 升序拼接 + isPortrait。
  String buildCacheKey(
    String platform,
    List<String> ids,
    List<String> names,
    bool isPortrait,
  ) {
    final sortedIds = List<String>.of(ids)..sort();
    final sortedNames = List<String>.of(names)..sort();
    return '$platform|${sortedIds.join(",")}|${sortedNames.join(",")}|$isPortrait';
  }

  bool _isExpired(ArtistPhotoCacheEntry entry) {
    return DateTime.now().difference(entry.cachedAt) > _ttl;
  }
}
