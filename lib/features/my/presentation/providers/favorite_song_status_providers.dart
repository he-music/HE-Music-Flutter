import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/favorite_song_key.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../data/datasources/favorite_song_cache_data_source.dart';
import '../../domain/entities/favorite_song_status_state.dart';

final favoriteSongCacheDataSourceProvider =
    Provider<FavoriteSongCacheDataSource>(
      (ref) => const FavoriteSongCacheDataSource(),
    );

class FavoriteSongStatusController extends Notifier<FavoriteSongStatusState> {
  int _revision = 0;
  Future<void> _cacheTail = Future<void>.value();
  late FavoriteSongCacheDataSource _cache;

  @override
  FavoriteSongStatusState build() {
    _cache = ref.read(favoriteSongCacheDataSourceProvider);
    ref.listen(
      appConfigProvider.select(
        (config) => (config.apiBaseUrl, config.authToken),
      ),
      (previous, next) {
        if (previous == next) return;
        if (!(next.$2?.trim().isNotEmpty ?? false)) {
          clear();
        } else {
          // Initial config hydration should retain the cache for offline startup.
          if (previous?.$2?.trim().isNotEmpty ?? false) clear();
          unawaited(_restoreAndRefresh());
        }
      },
    );
    if (ref.read(appConfigProvider).authToken?.trim().isNotEmpty ?? false) {
      Future.microtask(_restoreAndRefresh);
    }
    return FavoriteSongStatusState.initial;
  }

  void _persist(Future<void> Function() action) {
    _cacheTail = _cacheTail.then((_) => action()).catchError((
      Object _,
      StackTrace _,
    ) {
      // A cache failure must not undo a successful server-side favorite action.
    });
  }

  Future<void> _restoreAndRefresh() async {
    final revision = _revision;
    try {
      await _cacheTail;
      final cached = await _cache.read();
      if (!ref.mounted || revision != _revision) return;
      if (cached != null) _setItems(cached);
    } catch (_) {
      // The network can still populate the state when the local cache fails.
    }
    if (!ref.mounted || revision != _revision) return;
    try {
      await refresh();
    } catch (_) {
      // Keep cached favorites available offline; explicit refresh still throws.
    }
  }

  Future<void> refresh() async {
    final token = ref.read(appConfigProvider).authToken?.trim() ?? '';
    if (token.isEmpty) {
      clear();
      return;
    }
    final revision = ++_revision;
    final api = ref.read(onlineApiClientProvider);
    final items = <IdPlatformInfo>[];
    const pageSize = 1000;
    for (var page = 1; ; page++) {
      final result = await api.fetchFavoriteSongs(
        pageIndex: page,
        pageSize: pageSize,
      );
      if (!ref.mounted || revision != _revision) return;
      items.addAll(result);
      if (result.length < pageSize) break;
    }
    replaceAll(items);
  }

  void _setItems(List<IdPlatformInfo> items) {
    state = state.copyWith(
      songKeys: items
          .map(
            (item) =>
                buildFavoriteSongKey(songId: item.id, platform: item.platform),
          )
          .toSet(),
      ready: true,
    );
  }

  void replaceAll(List<IdPlatformInfo> items) {
    _revision++;
    _setItems(items);
    final snapshot = List<IdPlatformInfo>.of(items);
    _persist(() => _cache.replace(snapshot));
  }

  void addSong({required String songId, required String platform}) {
    _revision++;
    final next = <String>{...state.songKeys};
    next.add(buildFavoriteSongKey(songId: songId, platform: platform));
    state = state.copyWith(songKeys: next, ready: true);
    _persist(
      () => _cache.setSong(
        IdPlatformInfo(id: songId, platform: platform),
        liked: true,
      ),
    );
  }

  void removeSong({required String songId, required String platform}) {
    _revision++;
    final next = <String>{...state.songKeys};
    next.remove(buildFavoriteSongKey(songId: songId, platform: platform));
    state = state.copyWith(songKeys: next, ready: true);
    _persist(
      () => _cache.setSong(
        IdPlatformInfo(id: songId, platform: platform),
        liked: false,
      ),
    );
  }

  bool contains({required String songId, required String platform}) => state
      .songKeys
      .contains(buildFavoriteSongKey(songId: songId, platform: platform));

  void clear() {
    _revision++;
    state = FavoriteSongStatusState.initial;
    _persist(_cache.clear);
  }
}

final favoriteSongStatusProvider =
    NotifierProvider<FavoriteSongStatusController, FavoriteSongStatusState>(
      FavoriteSongStatusController.new,
    );
