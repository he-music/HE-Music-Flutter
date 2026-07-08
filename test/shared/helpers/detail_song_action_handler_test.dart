import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/my/data/datasources/my_collection_api_client.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/domain/entities/user_playlist_detail_request.dart';
import 'package:he_music_flutter/features/my/domain/repositories/user_playlist_detail_repository.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_collection_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/user_playlist_detail_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_content.dart';
import 'package:he_music_flutter/shared/helpers/detail_song_action_handler.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  testWidgets('addSelectedSongsToPlaylist refreshes created playlist shelf', (
    tester,
  ) async {
    final collectionClient = _FakeMyCollectionApiClient();
    final repository = _FakeUserPlaylistDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          myCollectionApiClientProvider.overrideWithValue(collectionClient),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          userPlaylistDetailRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: _ActionHost(
            song: _song,
            selectedSongKeys: const <String>{'qq|song-1'},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(collectionClient.createdPlaylistCalls, 0);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('目标歌单'));
    await tester.pumpAndSettle();

    expect(repository.addSongsCallCount, 1);
    expect(collectionClient.createdPlaylistCalls, 2);
  });
}

const _song = SongInfo(
  name: '歌曲',
  subtitle: '',
  id: 'song-1',
  duration: 200,
  mvId: '',
  album: SongInfoAlbumInfo(name: '专辑', id: 'album-1'),
  artists: <SongInfoArtistInfo>[SongInfoArtistInfo(id: 'artist-1', name: '歌手')],
  links: <LinkInfo>[],
  platform: 'qq',
  cover: '',
  sublist: <SongInfo>[],
  originalType: 0,
);

class _ActionHost extends ConsumerWidget {
  const _ActionHost({required this.song, required this.selectedSongKeys});

  final SongInfo song;
  final Set<String> selectedSongKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            final handler = DetailSongActionHandler(ref: ref);
            handler.addSelectedSongsToPlaylist(
              context,
              songs: <SongInfo>[song],
              selectedSongKeys: selectedSongKeys,
              submittingBatch: false,
            );
          },
          child: const Text('Add'),
        ),
      ),
    );
  }
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'zh');
  }
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: BigInt.zero,
      ),
    ];
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
        id: 'playlist-1',
        platform: 'qq',
        type: MyFavoriteType.playlists,
        title: '目标歌单',
        subtitle: '',
        coverUrl: '',
        songCount: '$createdPlaylistCalls',
      ),
    ];
  }
}

class _FakeUserPlaylistDetailRepository
    implements UserPlaylistDetailRepository {
  int addSongsCallCount = 0;

  @override
  Future<void> addSongs({
    required String playlistId,
    required List<IdPlatformInfo> songs,
  }) async {
    addSongsCallCount += 1;
  }

  @override
  Future<void> deletePlaylist(String id) async {}

  @override
  Future<PlaylistDetailContent> fetchDetail(
    UserPlaylistDetailRequest request,
  ) async {
    throw UnimplementedError();
  }

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
