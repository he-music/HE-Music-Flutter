import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_song_status_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/user_playlist_detail_request.dart';
import 'package:he_music_flutter/features/my/domain/repositories/user_playlist_detail_repository.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/user_playlist_detail_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/utils/favorite_song_key.dart';

void main() {
  test('removeSongs 从默认歌单移除歌曲后同步喜欢歌曲状态', () async {
    final repository = _FakeUserPlaylistDetailRepository(isDefault: true);
    final container = ProviderContainer(
      overrides: [
        userPlaylistDetailRepositoryProvider.overrideWithValue(repository),
        favoriteSongStatusProvider.overrideWith(_TestFavoriteSongStatus.new),
      ],
    );
    addTearDown(container.dispose);
    const request = UserPlaylistDetailRequest(id: 'playlist-1', title: 'T');
    final provider = userPlaylistDetailControllerProvider(request.cacheKey);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(provider.notifier);

    await controller.removeSongs(
      request: request,
      songs: const <IdPlatformInfo>[
        IdPlatformInfo(id: 'song-1', platform: 'qq'),
      ],
      isDefaultPlaylist: true,
    );

    final state = container.read(favoriteSongStatusProvider);
    expect(
      state.songKeys,
      isNot(contains(buildFavoriteSongKey(songId: 'song-1', platform: 'qq'))),
    );
  });
}

class _TestFavoriteSongStatus extends FavoriteSongStatusController {
  @override
  FavoriteSongStatusState build() {
    return FavoriteSongStatusState(
      songKeys: <String>{
        buildFavoriteSongKey(songId: 'song-1', platform: 'qq'),
      },
      ready: true,
    );
  }
}

class _FakeUserPlaylistDetailRepository
    implements UserPlaylistDetailRepository {
  const _FakeUserPlaylistDetailRepository({required this.isDefault});

  final bool isDefault;

  @override
  Future<PlaylistInfo> fetchInfo(UserPlaylistDetailRequest request) async {
    return PlaylistInfo(
      name: '测试歌单',
      id: request.id,
      cover: '',
      creator: 'me',
      songCount: '0',
      playCount: '0',
      songs: const <SongInfo>[],
      platform: 'user',
      description: '',
      isDefault: isDefault,
    );
  }

  @override
  Future<List<SongInfo>> fetchSongs(UserPlaylistDetailRequest request) async {
    return const <SongInfo>[];
  }

  @override
  Future<void> addSongs({
    required String playlistId,
    required List<IdPlatformInfo> songs,
  }) async {}

  @override
  Future<void> deletePlaylist(String id) async {}

  @override
  Future<void> removeSongs({
    required String playlistId,
    required List<IdPlatformInfo> songs,
  }) async {}

  @override
  Future<void> updatePlaylist({
    required String id,
    required String name,
    required String cover,
    required String description,
  }) async {}
}
