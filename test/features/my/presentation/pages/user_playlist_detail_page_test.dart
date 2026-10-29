import 'dart:async';

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
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_songs_page_result.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/song_list_count.dart';
import 'package:he_music_flutter/shared/widgets/animated_skeleton.dart';
import 'package:he_music_flutter/shared/widgets/detail_page_shell.dart';
import 'package:he_music_flutter/shared/widgets/song_info_list_section.dart';
import 'package:he_music_flutter/shared/widgets/song_sort_button.dart';

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

      expect(repository.fetchSongsCallCount, 1);
      expect(find.text('用户歌单首屏歌曲'), findsOneWidget);
    },
  );

  testWidgets(
    'user playlist detail reloads when opening the same playlist again',
    (tester) async {
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

      expect(repository.fetchSongsCallCount, 2);
      expect(find.text('新的喜欢歌曲'), findsOneWidget);
    },
  );

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

    expect(repository.fetchSongsCallCount, 1);
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

  testWidgets(
    'user playlist info replaces full skeleton while songs are pending',
    (tester) async {
      final repository = _ControlledUserPlaylistDetailRepository();
      const request = UserPlaylistDetailRequest(
        id: 'playlist-1',
        title: '渐进用户歌单',
      );

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
            home: UserPlaylistDetailPage(id: 'playlist-1', title: '渐进用户歌单'),
          ),
        ),
      );
      await tester.pump();

      repository.completeInfo(request);
      await tester.pump();

      expect(find.byType(DetailLoadingBody), findsNothing);
      expect(find.text('渐进用户歌单'), findsWidgets);
      expect(find.byType(SkeletonBox), findsWidgets);

      repository.completeSongs(request);
      await tester.pump();
    },
  );

  testWidgets(
    'user playlist list connects load more and retry without losing songs',
    (tester) async {
      final repository = _FakeUserPlaylistDetailRepository()
        ..nextPage = Completer<PlaylistDetailSongsPageResult>();
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
      var section = tester.widget<SongInfoListSection>(
        find.byType(SongInfoListSection),
      );
      expect(section.hasMore, isTrue);
      expect(section.enablePaging, isTrue);
      expect(
        tester.widget<SongSortButton>(find.byType(SongSortButton)).enabled,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('user-playlist-song-count')));
      await tester.pump();
      section = tester.widget<SongInfoListSection>(
        find.byType(SongInfoListSection),
      );
      expect(section.loadingMore, isTrue);
      repository.nextPage!.completeError(Exception('next page failed'));
      await tester.pump();
      await tester.pump();
      section = tester.widget<SongInfoListSection>(
        find.byType(SongInfoListSection),
      );
      expect(section.loadMoreErrorMessage, contains('next page failed'));
      expect(section.songs, hasLength(2));
      expect(find.text('用户歌单首屏歌曲'), findsOneWidget);
      repository.nextPage = Completer<PlaylistDetailSongsPageResult>();
      await tester.tap(find.byKey(const ValueKey('user-playlist-song-count')));
      await tester.pump();
      repository.nextPage!.complete(
        PlaylistDetailSongsPageResult(
          songs: [
            SongInfo.fromMap({
              'id': 'song-3',
              'name': '下一页歌曲',
              'platform': 'qq',
            }),
          ],
          pageIndex: 2,
          pageSize: playlistDetailSongsPageSize,
          totalCount: 1001,
          hasMore: false,
        ),
      );
      await tester.pump();
      await tester.pump();
      section = tester.widget<SongInfoListSection>(
        find.byType(SongInfoListSection),
      );
      expect(section.songs, hasLength(3));
      expect(section.hasMore, isFalse);
      expect(section.loadMoreErrorMessage, isNull);
      expect(
        tester.widget<SongSortButton>(find.byType(SongSortButton)).enabled,
        isTrue,
      );
      expect(
        tester
            .widget<SongSortButton>(find.byType(SongSortButton))
            .allowDuration,
        isFalse,
      );
      expect(repository.requestedPages, [1, 2, 2]);
      expect(
        tester
            .widget<SongListCount>(
              find.byKey(const ValueKey('user-playlist-song-count')),
            )
            .hasMore,
        isFalse,
      );
    },
  );
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

  int fetchSongsCallCount = 0;
  int deletePlaylistCallCount = 0;
  final bool isDefault;
  final List<String> songNamesByFetch;
  final requestedPages = <int>[];
  Completer<PlaylistDetailSongsPageResult>? nextPage;

  @override
  Future<PlaylistInfo> fetchInfo(UserPlaylistDetailRequest request) async {
    return PlaylistInfo(
      name: '测试歌单',
      id: request.id,
      cover: 'https://example.com/playlist.jpg',
      creator: '测试用户',
      songCount: '2',
      playCount: '10',
      songs: const <SongInfo>[],
      platform: 'qq',
      description: '测试歌单描述',
      isDefault: isDefault,
    );
  }

  @override
  Future<PlaylistDetailSongsPageResult> fetchSongs(
    UserPlaylistDetailRequest request, {
    int pageIndex = 1,
    int pageSize = playlistDetailSongsPageSize,
  }) async {
    fetchSongsCallCount += 1;
    requestedPages.add(pageIndex);
    if (pageIndex > 1) return nextPage!.future;
    final firstSongName = songNamesByFetch.isEmpty
        ? '用户歌单首屏歌曲'
        : songNamesByFetch[(fetchSongsCallCount - 1).clamp(
            0,
            songNamesByFetch.length - 1,
          )];
    final songs = <SongInfo>[
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
      ),
    ];
    return PlaylistDetailSongsPageResult(
      songs: songs,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalCount: nextPage == null ? songs.length : 1001,
      hasMore: nextPage != null,
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

class _ControlledUserPlaylistDetailRepository
    implements UserPlaylistDetailRepository {
  final _infoCompleter = Completer<PlaylistInfo>();
  final _songsCompleter = Completer<PlaylistDetailSongsPageResult>();

  @override
  Future<PlaylistInfo> fetchInfo(UserPlaylistDetailRequest request) {
    return _infoCompleter.future;
  }

  @override
  Future<PlaylistDetailSongsPageResult> fetchSongs(
    UserPlaylistDetailRequest request, {
    int pageIndex = 1,
    int pageSize = playlistDetailSongsPageSize,
  }) {
    return _songsCompleter.future;
  }

  void completeInfo(UserPlaylistDetailRequest request) {
    _infoCompleter.complete(
      PlaylistInfo(
        name: request.title,
        id: request.id,
        cover: '',
        creator: 'me',
        songCount: '',
        playCount: '',
        songs: const <SongInfo>[],
        platform: 'user',
        description: '',
      ),
    );
  }

  void completeSongs(UserPlaylistDetailRequest request) {
    _songsCompleter.complete(
      const PlaylistDetailSongsPageResult(
        songs: [],
        pageIndex: 1,
        pageSize: playlistDetailSongsPageSize,
        totalCount: 0,
        hasMore: false,
      ),
    );
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
