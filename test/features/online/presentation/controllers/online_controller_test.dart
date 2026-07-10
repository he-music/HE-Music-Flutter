import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/my/data/datasources/my_collection_api_client.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_collection_status_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_overview.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_profile.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_summary.dart';
import 'package:he_music_flutter/features/my/domain/repositories/my_overview_repository.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_collection_status_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_collection_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_overview_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_playlist_shelf_providers.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/utils/id_platform_key.dart';

void main() {
  test(
    'togglePlaylistFavorite adds playlist key and success message',
    () async {
      final client = _FakeOnlineApiClient();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          onlineApiClientProvider.overrideWithValue(client),
          favoriteCollectionStatusProvider.overrideWith(
            _TestFavoriteCollectionStatus.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(onlineControllerProvider.notifier)
          .togglePlaylistFavorite(
            playlistId: 'playlist-1',
            platform: 'kuwo',
            like: true,
          );

      final onlineState = container.read(onlineControllerProvider);
      final favoriteState = container.read(favoriteCollectionStatusProvider);

      expect(client.favoritePlaylistCalls, 1);
      expect(onlineState.message, 'Playlist favorited.');
      expect(
        favoriteState.playlistKeys,
        contains(buildIdPlatformKey(id: 'playlist-1', platform: 'kuwo')),
      );
    },
  );

  test(
    'togglePlaylistFavorite removes playlist key when unfavoriting',
    () async {
      final client = _FakeOnlineApiClient();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          onlineApiClientProvider.overrideWithValue(client),
          favoriteCollectionStatusProvider.overrideWith(
            _TestFavoriteCollectionStatus.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final statusController = container.read(
        favoriteCollectionStatusProvider.notifier,
      );
      statusController.add(
        type: MyFavoriteType.playlists,
        id: 'playlist-1',
        platform: 'kuwo',
      );

      await container
          .read(onlineControllerProvider.notifier)
          .togglePlaylistFavorite(
            playlistId: 'playlist-1',
            platform: 'kuwo',
            like: false,
          );

      final onlineState = container.read(onlineControllerProvider);
      final favoriteState = container.read(favoriteCollectionStatusProvider);

      expect(client.unfavoritePlaylistCalls, 1);
      expect(onlineState.message, 'Playlist unfavorited.');
      expect(
        favoriteState.playlistKeys,
        isNot(contains(buildIdPlatformKey(id: 'playlist-1', platform: 'kuwo'))),
      );
    },
  );

  test(
    'toggleSongFavorite refreshes overview and created playlist shelf',
    () async {
      final client = _FakeOnlineApiClient();
      final collectionClient = _FakeMyCollectionApiClient();
      final overviewRepository = _FakeMyOverviewRepository();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          onlineApiClientProvider.overrideWithValue(client),
          myCollectionApiClientProvider.overrideWithValue(collectionClient),
          myOverviewRepositoryProvider.overrideWithValue(overviewRepository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(myCreatedPlaylistsProvider.future);
      await container.read(myOverviewControllerProvider.notifier).initialize();

      await container
          .read(onlineControllerProvider.notifier)
          .toggleSongFavorite(songId: 'song-1', platform: 'qq', like: true);

      await container.read(myCreatedPlaylistsProvider.future);
      final overviewState = container.read(myOverviewControllerProvider);

      expect(client.favoriteSongCalls, 1);
      expect(collectionClient.createdPlaylistCalls, 2);
      expect(overviewRepository.fetchOverviewCalls, 2);
      expect(overviewState.overview?.summary.favoriteSongCount, 2);
    },
  );

  test('logout clears token and cached account overview', () async {
    final collectionClient = _FakeMyCollectionApiClient();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_TestAppConfigController.new),
        onlineApiClientProvider.overrideWithValue(_FakeOnlineApiClient()),
        myCollectionApiClientProvider.overrideWithValue(collectionClient),
        myOverviewRepositoryProvider.overrideWithValue(
          _FakeMyOverviewRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(myOverviewControllerProvider.notifier).initialize();
    await container.read(myCreatedPlaylistsProvider.future);
    expect(container.read(myOverviewControllerProvider).overview, isNotNull);

    await container.read(onlineControllerProvider.notifier).logout();

    expect(container.read(appConfigProvider).authToken, isNull);
    expect(container.read(myOverviewControllerProvider).overview, isNull);
    expect(await container.read(myCreatedPlaylistsProvider.future), isEmpty);
    expect(collectionClient.createdPlaylistCalls, 1);
  });
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(authToken: 'token');
  }

  @override
  void clearAuthToken() {
    state = state.copyWith(clearToken: true, clearRefreshToken: true);
  }
}

class _FakeOnlineApiClient extends OnlineApiClient {
  _FakeOnlineApiClient() : super(Dio());

  int favoritePlaylistCalls = 0;
  int unfavoritePlaylistCalls = 0;
  int favoriteSongCalls = 0;

  @override
  Future<List<IdPlatformInfo>> fetchFavoriteSongs({
    int pageIndex = 1,
    int pageSize = 1000,
  }) async {
    return const <IdPlatformInfo>[];
  }

  @override
  Future<Map<String, dynamic>> togglePlaylistFavorite({
    required String playlistId,
    required String platform,
    required bool like,
    String? name,
    String? cover,
    String? creator,
  }) async {
    if (like) {
      favoritePlaylistCalls += 1;
      return <String, dynamic>{'status': 'ok'};
    }
    unfavoritePlaylistCalls += 1;
    return <String, dynamic>{'status': 'ok'};
  }

  @override
  Future<Map<String, dynamic>> toggleSongFavorite({
    required String songId,
    required String platform,
    required bool like,
  }) async {
    if (like) {
      favoriteSongCalls += 1;
    }
    return <String, dynamic>{'status': 'ok'};
  }
}

class _FakeMyCollectionApiClient extends MyCollectionApiClient {
  _FakeMyCollectionApiClient() : super(Dio());

  int createdPlaylistCalls = 0;

  @override
  Future<List<MyFavoriteItem>> fetchCreatedPlaylists() async {
    createdPlaylistCalls += 1;
    return <MyFavoriteItem>[
      MyFavoriteItem(
        id: 'default',
        platform: 'qq',
        type: MyFavoriteType.playlists,
        title: '我喜欢的音乐',
        subtitle: '',
        coverUrl: '',
        songCount: '$createdPlaylistCalls',
        isDefault: true,
      ),
    ];
  }
}

class _FakeMyOverviewRepository implements MyOverviewRepository {
  int fetchOverviewCalls = 0;

  @override
  Future<MyOverview> fetchOverview() async {
    fetchOverviewCalls += 1;
    return MyOverview(
      profile: const MyProfile(
        id: 'user-1',
        username: 'user',
        nickname: 'User',
        email: '',
        status: 1,
        avatarUrl: '',
      ),
      summary: MySummary(
        favoriteSongCount: fetchOverviewCalls,
        favoritePlaylistCount: 0,
        favoriteArtistCount: 0,
        favoriteAlbumCount: 0,
        createdPlaylistCount: 1,
      ),
    );
  }
}

class _TestFavoriteCollectionStatus
    extends FavoriteCollectionStatusController {
  @override
  FavoriteCollectionStatusState build() {
    return FavoriteCollectionStatusState.initial;
  }
}
