import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_collection_status_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_song_status_state.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_collection_status_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_request.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_songs_page_result.dart';
import 'package:he_music_flutter/features/playlist/domain/repositories/playlist_detail_repository.dart';
import 'package:he_music_flutter/features/playlist/presentation/pages/playlist_detail_page.dart';
import 'package:he_music_flutter/features/playlist/presentation/providers/playlist_detail_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/utils/id_platform_key.dart';
import 'package:he_music_flutter/shared/widgets/animated_skeleton.dart';
import 'package:he_music_flutter/shared/widgets/detail_page_shell.dart';

void main() {
  testWidgets('playlist detail favorite icon uses error color when liked', (
    tester,
  ) async {
    final repository = _FakePlaylistDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          playlistDetailRepositoryProvider.overrideWithValue(repository),
          favoriteSongStatusProvider.overrideWith(
            _TestFavoriteSongStatusController.new,
          ),
          favoriteCollectionStatusProvider.overrideWith(
            _LikedPlaylistCollectionStatusController.new,
          ),
        ],
        child: const MaterialApp(
          home: PlaylistDetailPage(
            id: 'playlist-1',
            platform: 'qq',
            title: '测试歌单',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final icon = tester.widget<Icon>(find.byIcon(Icons.favorite_rounded).first);
    final context = tester.element(find.byType(PlaylistDetailPage));

    expect(icon.color, Theme.of(context).colorScheme.error);
  });

  testWidgets('switching playlists never shows the previous content', (
    tester,
  ) async {
    final repository = _ControlledPlaylistDetailRepository();
    var currentRequest = const PlaylistDetailRequest(
      id: 'playlist-a',
      platform: 'qq',
      title: '歌单 A',
    );
    late StateSetter updateHost;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          playlistDetailRepositoryProvider.overrideWithValue(repository),
          favoriteSongStatusProvider.overrideWith(
            _TestFavoriteSongStatusController.new,
          ),
          favoriteCollectionStatusProvider.overrideWith(
            _LikedPlaylistCollectionStatusController.new,
          ),
        ],
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return PlaylistDetailPage(
                key: ValueKey(currentRequest.cacheKey),
                id: currentRequest.id,
                platform: currentRequest.platform,
                title: currentRequest.title,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    repository.complete(currentRequest);
    await tester.pump();
    expect(find.text('歌单 A'), findsWidgets);

    const requestB = PlaylistDetailRequest(
      id: 'playlist-b',
      platform: 'qq',
      title: '歌单 B',
    );
    updateHost(() => currentRequest = requestB);
    await tester.pump();

    expect(find.byType(DetailLoadingBody), findsOneWidget);
    expect(find.text('歌单 A'), findsNothing);

    repository.complete(requestB);
    await tester.pump();
    expect(find.text('歌单 B'), findsWidgets);
  });

  testWidgets('playlist info replaces full skeleton while songs are pending', (
    tester,
  ) async {
    final repository = _ControlledPlaylistDetailRepository();
    const request = PlaylistDetailRequest(
      id: 'playlist-1',
      platform: 'qq',
      title: '渐进歌单',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          playlistDetailRepositoryProvider.overrideWithValue(repository),
          favoriteSongStatusProvider.overrideWith(
            _TestFavoriteSongStatusController.new,
          ),
          favoriteCollectionStatusProvider.overrideWith(
            _LikedPlaylistCollectionStatusController.new,
          ),
        ],
        child: const MaterialApp(
          home: PlaylistDetailPage(
            id: 'playlist-1',
            platform: 'qq',
            title: '渐进歌单',
          ),
        ),
      ),
    );
    await tester.pump();

    repository.completeInfo(request);
    await tester.pump();

    expect(find.byType(DetailLoadingBody), findsNothing);
    expect(find.text('渐进歌单'), findsWidgets);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.text('暂无歌曲'), findsNothing);

    repository.completeSongs(request);
    await tester.pump();
  });

  testWidgets('scroll loads next page and failed page can retry', (
    tester,
  ) async {
    final repository = _PagingPlaylistDetailRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
          playerControllerProvider.overrideWith(_TestPlayerController.new),
          onlinePlatformsProvider.overrideWith(
            _TestOnlinePlatformsController.new,
          ),
          playlistDetailRepositoryProvider.overrideWithValue(repository),
          favoriteSongStatusProvider.overrideWith(
            _TestFavoriteSongStatusController.new,
          ),
          favoriteCollectionStatusProvider.overrideWith(
            _LikedPlaylistCollectionStatusController.new,
          ),
        ],
        child: const MaterialApp(
          home: PlaylistDetailPage(
            id: 'playlist-1',
            platform: 'qq',
            title: '分页歌单',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('歌曲 0'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pump();

    expect(repository.requestedPageIndexes, <int>[1, 2]);
    repository.failLatestPage();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlaylistDetailPage)),
    );
    expect(
      container
          .read(playlistDetailControllerProvider('qq|playlist-1'))
          .loadMoreErrorMessage,
      contains('page failed'),
    );
    expect(find.text('歌曲 19'), findsOneWidget);
    expect(find.textContaining('page failed'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(repository.requestedPageIndexes, <int>[1, 2, 2]);

    repository.completeLatestPage();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('追加歌曲'), findsOneWidget);
    expect(find.textContaining('page failed'), findsNothing);
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

class _LikedPlaylistCollectionStatusController
    extends FavoriteCollectionStatusController {
  @override
  FavoriteCollectionStatusState build() {
    return FavoriteCollectionStatusState(
      playlistKeys: <String>{
        buildIdPlatformKey(id: 'playlist-1', platform: 'qq'),
      },
      artistKeys: const <String>{},
      albumKeys: const <String>{},
      ready: true,
    );
  }
}

class _FakePlaylistDetailRepository implements PlaylistDetailRepository {
  @override
  Future<PlaylistInfo> fetchInfo(PlaylistDetailRequest request) async {
    return PlaylistInfo(
      name: '测试歌单',
      id: request.id,
      cover: 'https://example.com/cover.jpg',
      creator: '测试用户',
      songCount: '1',
      playCount: '10',
      songs: const <SongInfo>[],
      platform: request.platform,
      description: '测试描述',
    );
  }

  @override
  Future<PlaylistDetailSongsPageResult> fetchSongs(
    PlaylistDetailRequest request, {
    int pageIndex = 1,
    int pageSize = playlistDetailSongsPageSize,
  }) async {
    return PlaylistDetailSongsPageResult(
      songs: const <SongInfo>[],
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalCount: 0,
      hasMore: false,
    );
  }
}

class _ControlledPlaylistDetailRepository implements PlaylistDetailRepository {
  final Map<String, Completer<PlaylistInfo>> _infoCompleters = {};
  final Map<String, Completer<PlaylistDetailSongsPageResult>> _songCompleters =
      {};

  @override
  Future<PlaylistInfo> fetchInfo(PlaylistDetailRequest request) {
    return (_infoCompleters[request.cacheKey] ??= Completer<PlaylistInfo>())
        .future;
  }

  @override
  Future<PlaylistDetailSongsPageResult> fetchSongs(
    PlaylistDetailRequest request, {
    int pageIndex = 1,
    int pageSize = playlistDetailSongsPageSize,
  }) {
    return (_songCompleters[request.cacheKey] ??=
            Completer<PlaylistDetailSongsPageResult>())
        .future;
  }

  void complete(PlaylistDetailRequest request) {
    completeInfo(request);
    completeSongs(request);
  }

  void completeInfo(PlaylistDetailRequest request) {
    _infoCompleters[request.cacheKey]!.complete(
      PlaylistInfo(
        name: request.title,
        id: request.id,
        cover: '',
        creator: '',
        songCount: '0',
        playCount: '0',
        songs: const <SongInfo>[],
        platform: request.platform,
        description: '',
      ),
    );
  }

  void completeSongs(PlaylistDetailRequest request) {
    _songCompleters[request.cacheKey]!.complete(
      const PlaylistDetailSongsPageResult(
        songs: <SongInfo>[],
        pageIndex: 1,
        pageSize: playlistDetailSongsPageSize,
        totalCount: 0,
        hasMore: false,
      ),
    );
  }
}

class _PagingPlaylistDetailRepository implements PlaylistDetailRepository {
  final List<int> requestedPageIndexes = <int>[];
  final List<Completer<PlaylistDetailSongsPageResult>> _pendingPages =
      <Completer<PlaylistDetailSongsPageResult>>[];

  @override
  Future<PlaylistInfo> fetchInfo(PlaylistDetailRequest request) async {
    return PlaylistInfo(
      name: request.title,
      id: request.id,
      cover: '',
      creator: '',
      songCount: '21',
      playCount: '0',
      songs: const <SongInfo>[],
      platform: request.platform,
      description: '',
    );
  }

  @override
  Future<PlaylistDetailSongsPageResult> fetchSongs(
    PlaylistDetailRequest request, {
    int pageIndex = 1,
    int pageSize = playlistDetailSongsPageSize,
  }) {
    requestedPageIndexes.add(pageIndex);
    if (pageIndex == 1) {
      return Future<PlaylistDetailSongsPageResult>.value(
        PlaylistDetailSongsPageResult(
          songs: List<SongInfo>.generate(20, _pagingSong),
          pageIndex: 1,
          pageSize: 20,
          totalCount: 21,
          hasMore: true,
        ),
      );
    }
    final completer = Completer<PlaylistDetailSongsPageResult>();
    _pendingPages.add(completer);
    return completer.future;
  }

  void failLatestPage() {
    _pendingPages.last.completeError(Exception('page failed'));
  }

  void completeLatestPage() {
    _pendingPages.last.complete(
      PlaylistDetailSongsPageResult(
        songs: <SongInfo>[_pagingSong(20)],
        pageIndex: 2,
        pageSize: 20,
        totalCount: 21,
        hasMore: false,
      ),
    );
  }
}

SongInfo _pagingSong(int index) {
  return SongInfo(
    name: index == 20 ? '追加歌曲' : '歌曲 $index',
    subtitle: '',
    id: 'song-$index',
    duration: 180,
    mvId: '',
    album: const SongInfoAlbumInfo(name: '', id: ''),
    artists: const <SongInfoArtistInfo>[],
    links: const <LinkInfo>[],
    platform: 'qq',
    cover: '',
  );
}
