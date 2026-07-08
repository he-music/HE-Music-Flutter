import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_song_status_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/user_playlist_detail_request.dart';
import 'package:he_music_flutter/features/my/domain/repositories/user_playlist_detail_repository.dart';
import 'package:he_music_flutter/features/my/presentation/pages/user_playlist_detail_page.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/user_playlist_detail_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_content.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  testWidgets(
    'user playlist detail shows songs from detail payload on first paint',
    (tester) async {
      final repository = _FakeUserPlaylistDetailRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWith(_TestAppConfigController.new),
            playerControllerProvider.overrideWith(_TestPlayerController.new),
            onlinePlatformsProvider.overrideWith(
              _TestOnlinePlatformsController.new,
            ),
            favoriteSongStatusProvider.overrideWith(
              _TestFavoriteSongStatusController.new,
            ),
            userPlaylistDetailRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: UserPlaylistDetailPage(id: 'playlist-1', title: '测试歌单'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(repository.fetchDetailCallCount, 1);
      expect(find.text('用户歌单首屏歌曲'), findsOneWidget);
    },
  );

  testWidgets('user playlist detail reloads when opening the same playlist again', (
    tester,
  ) async {
    final repository = _FakeUserPlaylistDetailRepository(
      songNamesByFetch: const <String>['旧的喜欢歌曲', '新的喜欢歌曲'],
    );
    var showDetail = true;
    late StateSetter setHostState;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          favoriteSongStatusProvider.overrideWith(
            _TestFavoriteSongStatusController.new,
          ),
          userPlaylistDetailRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return showDetail
                  ? const UserPlaylistDetailPage(
                      id: 'playlist-1',
                      title: '测试歌单',
                    )
                  : const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    setHostState(() => showDetail = false);
    await tester.pump();

    setHostState(() => showDetail = true);
    await tester.pump();
    await tester.pump();

    expect(repository.fetchDetailCallCount, 2);
    expect(find.text('新的喜欢歌曲'), findsOneWidget);
  });

  testWidgets('user playlist detail enters batch mode and toggles songs', (
    tester,
  ) async {
    final repository = _FakeUserPlaylistDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          favoriteSongStatusProvider.overrideWith(
            _TestFavoriteSongStatusController.new,
          ),
          userPlaylistDetailRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: UserPlaylistDetailPage(id: 'playlist-1', title: '测试歌单'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Batch'));
    await tester.pump();

    await tester.tap(find.text('用户歌单首屏歌曲'));
    await tester.pump();

    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('user playlist detail handles non-numeric playlist id', (
    tester,
  ) async {
    final repository = _FakeUserPlaylistDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          favoriteSongStatusProvider.overrideWith(
            _TestFavoriteSongStatusController.new,
          ),
          userPlaylistDetailRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: UserPlaylistDetailPage(id: 'playlist-abc', title: '测试歌单'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(repository.fetchDetailCallCount, 1);
    expect(find.text('用户歌单首屏歌曲'), findsOneWidget);
  });

  testWidgets('default user playlist disables delete action', (tester) async {
    final repository = _FakeUserPlaylistDetailRepository(isDefault: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          favoriteSongStatusProvider.overrideWith(
            _TestFavoriteSongStatusController.new,
          ),
          userPlaylistDetailRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: UserPlaylistDetailPage(id: 'playlist-1', title: '测试歌单'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();

    expect(find.text('默认歌单不可删除'), findsOneWidget);
    await tester.tap(find.text('删除歌单'));
    await tester.pumpAndSettle();

    expect(repository.deletePlaylistCallCount, 0);
    expect(find.text('确认删除这个歌单？删除后不可恢复。'), findsNothing);
  });
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: 'zh',
      apiBaseUrl: 'https://example.com',
      authToken: 'token',
    );
  }
}

class _TestPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[]);
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

class _TestFavoriteSongStatusController extends FavoriteSongStatusController {
  @override
  FavoriteSongStatusState build() {
    return const FavoriteSongStatusState(songKeys: <String>{}, ready: true);
  }
}

class _FakeUserPlaylistDetailRepository
    implements UserPlaylistDetailRepository {
  _FakeUserPlaylistDetailRepository({
    this.isDefault = false,
    this.songNamesByFetch = const <String>[],
  });

  int fetchDetailCallCount = 0;
  int deletePlaylistCallCount = 0;
  final bool isDefault;
  final List<String> songNamesByFetch;

  @override
  Future<PlaylistDetailContent> fetchDetail(
    UserPlaylistDetailRequest request,
  ) async {
    fetchDetailCallCount += 1;
    final firstSongName = songNamesByFetch.isEmpty
        ? '用户歌单首屏歌曲'
        : songNamesByFetch[(fetchDetailCallCount - 1).clamp(
            0,
            songNamesByFetch.length - 1,
          )];
    return PlaylistDetailContent(
      info: PlaylistInfo(
        name: '测试歌单',
        id: request.id,
        cover: 'https://example.com/playlist.jpg',
        creator: '测试用户',
        songCount: '2',
        playCount: '10',
        songs: const <SongInfo>[
          SongInfo(
            name: '用户歌单首屏歌曲',
            subtitle: '',
            id: 'song-1',
            duration: 240,
            mvId: '',
            album: SongInfoAlbumInfo(name: '专辑 A', id: 'album-1'),
            artists: <SongInfoArtistInfo>[
              SongInfoArtistInfo(id: 'artist-1', name: '歌手 A'),
            ],
            links: <LinkInfo>[],
            platform: 'qq',
            cover: 'https://example.com/song-1.jpg',
            sublist: <SongInfo>[],
            originalType: 0,
          ),
          SongInfo(
            name: '用户歌单第二首',
            subtitle: '',
            id: 'song-2',
            duration: 200,
            mvId: '',
            album: SongInfoAlbumInfo(name: '专辑 B', id: 'album-2'),
            artists: <SongInfoArtistInfo>[
              SongInfoArtistInfo(id: 'artist-2', name: '歌手 B'),
            ],
            links: <LinkInfo>[],
            platform: 'qq',
            cover: 'https://example.com/song-2.jpg',
            sublist: <SongInfo>[],
            originalType: 0,
          ),
        ],
        platform: 'qq',
        description: '测试歌单描述',
        isDefault: isDefault,
      ),
      songs: <SongInfo>[
        SongInfo(
          name: firstSongName,
          subtitle: '',
          id: 'song-1',
          duration: 240,
          mvId: '',
          album: SongInfoAlbumInfo(name: '专辑 A', id: 'album-1'),
          artists: <SongInfoArtistInfo>[
            SongInfoArtistInfo(id: 'artist-1', name: '歌手 A'),
          ],
          links: <LinkInfo>[],
          platform: 'qq',
          cover: 'https://example.com/song-1.jpg',
          sublist: <SongInfo>[],
          originalType: 0,
        ),
        SongInfo(
          name: '用户歌单第二首',
          subtitle: '',
          id: 'song-2',
          duration: 200,
          mvId: '',
          album: SongInfoAlbumInfo(name: '专辑 B', id: 'album-2'),
          artists: <SongInfoArtistInfo>[
            SongInfoArtistInfo(id: 'artist-2', name: '歌手 B'),
          ],
          links: <LinkInfo>[],
          platform: 'qq',
          cover: 'https://example.com/song-2.jpg',
          sublist: <SongInfo>[],
          originalType: 0,
        ),
      ],
    );
  }

  @override
  Future<void> deletePlaylist(String id) async {
    deletePlaylistCallCount += 1;
  }

  @override
  Future<void> updatePlaylist({
    required String id,
    required String name,
    required String cover,
    required String description,
  }) async {}

  @override
  Future<void> addSongs({
    required String playlistId,
    required List<IdPlatformInfo> songs,
  }) async {}

  @override
  Future<void> removeSongs({
    required String playlistId,
    required List<IdPlatformInfo> songs,
  }) async {}
}
