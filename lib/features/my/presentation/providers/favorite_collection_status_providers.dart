import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/in_flight_request_cache.dart';
import '../../../../shared/utils/id_platform_key.dart';
import '../../domain/entities/favorite_collection_status_state.dart';
import '../../domain/entities/my_favorite_item.dart';
import '../../domain/entities/my_favorite_type.dart';
import 'my_collection_providers.dart';

class FavoriteCollectionStatusController
    extends Notifier<FavoriteCollectionStatusState> {
  final _refreshRequests = InFlightRequestCache<String, void>();

  @override
  FavoriteCollectionStatusState build() {
    ref.listen<String?>(
      appConfigProvider.select((config) => config.authToken),
      (previous, next) {
        final previousToken = previous?.trim() ?? '';
        final nextToken = next?.trim() ?? '';
        if (previousToken != nextToken) {
          clear();
        }
      },
    );
    return FavoriteCollectionStatusState.initial;
  }

  Future<void> ensureReady() {
    if (state.ready) {
      return Future<void>.value();
    }
    return refresh();
  }

  Future<void> refresh() async {
    final token = ref.read(appConfigProvider).authToken?.trim() ?? '';
    if (token.isEmpty) {
      clear();
      return;
    }
    await _refreshRequests.run(token, () => _refreshForToken(token));
  }

  Future<void> _refreshForToken(String token) async {
    final client = ref.read(myCollectionApiClientProvider);
    final results =
        await Future.wait<List<IdPlatformInfo>>(<Future<List<IdPlatformInfo>>>[
          client.fetchFavoriteIdPlatforms(MyFavoriteType.playlists),
          client.fetchFavoriteIdPlatforms(MyFavoriteType.artists),
          client.fetchFavoriteIdPlatforms(MyFavoriteType.albums),
        ]);
    if (!ref.mounted ||
        token != (ref.read(appConfigProvider).authToken?.trim() ?? '')) {
      return;
    }
    final playlists = results[0];
    final artists = results[1];
    final albums = results[2];
    replaceAll(playlists: playlists, artists: artists, albums: albums);
  }

  void replaceAll({
    required List<IdPlatformInfo> playlists,
    required List<IdPlatformInfo> artists,
    required List<IdPlatformInfo> albums,
  }) {
    state = state.copyWith(
      playlistKeys: _buildKeys(playlists),
      artistKeys: _buildKeys(artists),
      albumKeys: _buildKeys(albums),
      ready: true,
    );
  }

  void replaceAllItems({
    required List<MyFavoriteItem> playlists,
    required List<MyFavoriteItem> artists,
    required List<MyFavoriteItem> albums,
  }) {
    state = state.copyWith(
      playlistKeys: _buildItemKeys(playlists),
      artistKeys: _buildItemKeys(artists),
      albumKeys: _buildItemKeys(albums),
      ready: true,
    );
  }

  void addPlaylist({required String id, required String platform}) {
    final next = <String>{...state.playlistKeys};
    next.add(buildIdPlatformKey(id: id, platform: platform));
    state = state.copyWith(playlistKeys: next, ready: true);
  }

  void add({
    required MyFavoriteType type,
    required String id,
    required String platform,
  }) {
    final key = buildIdPlatformKey(id: id, platform: platform);
    switch (type) {
      case MyFavoriteType.songs:
        return;
      case MyFavoriteType.playlists:
        final next = <String>{...state.playlistKeys};
        next.add(key);
        state = state.copyWith(playlistKeys: next, ready: true);
      case MyFavoriteType.artists:
        final next = <String>{...state.artistKeys};
        next.add(key);
        state = state.copyWith(artistKeys: next, ready: true);
      case MyFavoriteType.albums:
        final next = <String>{...state.albumKeys};
        next.add(key);
        state = state.copyWith(albumKeys: next, ready: true);
    }
  }

  void remove({
    required MyFavoriteType type,
    required String id,
    required String platform,
  }) {
    final key = buildIdPlatformKey(id: id, platform: platform);
    switch (type) {
      case MyFavoriteType.songs:
        return;
      case MyFavoriteType.playlists:
        final next = <String>{...state.playlistKeys};
        next.remove(key);
        state = state.copyWith(playlistKeys: next, ready: true);
      case MyFavoriteType.artists:
        final next = <String>{...state.artistKeys};
        next.remove(key);
        state = state.copyWith(artistKeys: next, ready: true);
      case MyFavoriteType.albums:
        final next = <String>{...state.albumKeys};
        next.remove(key);
        state = state.copyWith(albumKeys: next, ready: true);
    }
  }

  bool containsPlaylist({required String id, required String platform}) {
    return state.playlistKeys.contains(
      buildIdPlatformKey(id: id, platform: platform),
    );
  }

  bool containsArtist({required String id, required String platform}) {
    return state.artistKeys.contains(
      buildIdPlatformKey(id: id, platform: platform),
    );
  }

  bool containsAlbum({required String id, required String platform}) {
    return state.albumKeys.contains(
      buildIdPlatformKey(id: id, platform: platform),
    );
  }

  void clear() {
    state = FavoriteCollectionStatusState.initial;
  }

  Set<String> _buildKeys(List<IdPlatformInfo> items) {
    return items
        .map((item) => buildIdPlatformKey(id: item.id, platform: item.platform))
        .toSet();
  }

  Set<String> _buildItemKeys(List<MyFavoriteItem> items) {
    return items
        .map((item) => buildIdPlatformKey(id: item.id, platform: item.platform))
        .toSet();
  }
}

final favoriteCollectionStatusProvider =
    NotifierProvider<
      FavoriteCollectionStatusController,
      FavoriteCollectionStatusState
    >(FavoriteCollectionStatusController.new);
