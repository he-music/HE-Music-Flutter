import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_request.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_songs_page_result.dart';
import 'package:he_music_flutter/features/playlist/domain/repositories/playlist_detail_repository.dart';
import 'package:he_music_flutter/features/playlist/presentation/providers/playlist_detail_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test(
    'late result from another playlist cannot replace current state',
    () async {
      final repository = _ControlledPlaylistDetailRepository();
      final container = ProviderContainer(
        overrides: [
          playlistDetailRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      const requestA = PlaylistDetailRequest(
        id: 'playlist-a',
        platform: 'qq',
        title: '歌单 A',
      );
      const requestB = PlaylistDetailRequest(
        id: 'playlist-b',
        platform: 'qq',
        title: '歌单 B',
      );
      final providerA = playlistDetailControllerProvider(requestA.cacheKey);
      final providerB = playlistDetailControllerProvider(requestB.cacheKey);
      final subscriptionA = container.listen(providerA, (_, _) {});
      final subscriptionB = container.listen(providerB, (_, _) {});
      addTearDown(subscriptionA.close);
      addTearDown(subscriptionB.close);

      final loadingA = container.read(providerA.notifier).initialize(requestA);
      final loadingB = container.read(providerB.notifier).initialize(requestB);

      repository.completeInfo(requestB);
      repository.completeSongs(requestB);
      await loadingB;
      expect(container.read(providerB).content?.title, '歌单 B');

      repository.completeInfo(requestA);
      repository.completeSongs(requestA);
      await loadingA;
      expect(container.read(providerA).content?.title, '歌单 A');
      expect(container.read(providerB).content?.title, '歌单 B');
    },
  );

  test('info is exposed while songs are still loading', () async {
    final repository = _ControlledPlaylistDetailRepository();
    final container = ProviderContainer(
      overrides: [
        playlistDetailRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    const request = PlaylistDetailRequest(
      id: 'playlist-1',
      platform: 'qq',
      title: '测试歌单',
    );
    final provider = playlistDetailControllerProvider(request.cacheKey);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    final loading = container.read(provider.notifier).initialize(request);

    expect(repository.fetchInfoCallCount(request), 1);
    expect(repository.fetchSongsCallCount(request), 1);

    repository.completeInfo(request);
    await container.pump();

    final state = container.read(provider);
    expect(state.loading, false);
    expect(state.content?.title, '测试歌单');
    expect(state.songsLoading, true);
    expect(state.songs, isEmpty);

    repository.completeSongs(request);
    await loading;
  });

  test(
    'songs can complete before info without exposing partial content',
    () async {
      final repository = _ControlledPlaylistDetailRepository();
      final container = ProviderContainer(
        overrides: [
          playlistDetailRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      const request = PlaylistDetailRequest(
        id: 'playlist-1',
        platform: 'qq',
        title: '测试歌单',
      );
      final provider = playlistDetailControllerProvider(request.cacheKey);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final loading = container.read(provider.notifier).initialize(request);

      repository.completeSongs(request, songs: <SongInfo>[_song()]);
      await container.pump();

      expect(container.read(provider).content, isNull);
      expect(container.read(provider).songs, hasLength(1));

      repository.completeInfo(request);
      await loading;

      expect(container.read(provider).content?.songs, hasLength(1));
    },
  );

  test(
    'song failure keeps info visible and retry only reloads songs',
    () async {
      final repository = _ControlledPlaylistDetailRepository();
      final container = ProviderContainer(
        overrides: [
          playlistDetailRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      const request = PlaylistDetailRequest(
        id: 'playlist-1',
        platform: 'qq',
        title: '测试歌单',
      );
      final provider = playlistDetailControllerProvider(request.cacheKey);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(provider.notifier);
      final loading = controller.initialize(request);

      repository.completeInfo(request);
      repository.failSongs(request);
      await loading;

      expect(container.read(provider).content?.title, '测试歌单');
      expect(
        container.read(provider).songsErrorMessage,
        contains('songs failed'),
      );

      final retrying = controller.retrySongs(request);
      expect(repository.fetchInfoCallCount(request), 1);
      expect(repository.fetchSongsCallCount(request), 2);
      repository.completeSongs(request, songs: <SongInfo>[_song()]);
      await retrying;

      expect(container.read(provider).songs, hasLength(1));
      expect(container.read(provider).songsErrorMessage, isNull);
    },
  );

  test(
    'loadMore uses response cursor, appends unique songs, and stops',
    () async {
      final repository = _ControlledPlaylistDetailRepository();
      final container = ProviderContainer(
        overrides: [
          playlistDetailRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      const request = PlaylistDetailRequest(
        id: 'playlist-1',
        platform: 'qq',
        title: '测试歌单',
      );
      final provider = playlistDetailControllerProvider(request.cacheKey);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(provider.notifier);
      final loading = controller.initialize(request);

      repository.completeInfo(request);
      repository.completeSongs(
        request,
        songs: <SongInfo>[_song('song-1'), _song('song-2')],
        pageIndex: 3,
        pageSize: 300,
        totalCount: 4,
        hasMore: true,
      );
      await loading;

      final loadingMore = controller.loadMore(request);
      expect(repository.fetchSongsCallCount(request), 2);
      expect(repository.lastSongsCall(request).pageIndex, 4);
      expect(repository.lastSongsCall(request).pageSize, 300);

      await controller.loadMore(request);
      expect(repository.fetchSongsCallCount(request), 2);

      repository.completeSongs(
        request,
        songs: <SongInfo>[
          _song('song-2'),
          _song('song-2', 'netease'),
          _song('song-3'),
        ],
        pageIndex: 4,
        pageSize: 200,
        totalCount: 4,
        hasMore: false,
      );
      await loadingMore;

      final state = container.read(provider);
      expect(state.songs.map((song) => '${song.platform}|${song.id}'), <String>[
        'qq|song-1',
        'qq|song-2',
        'netease|song-2',
        'qq|song-3',
      ]);
      expect(state.pageIndex, 4);
      expect(state.pageSize, 200);
      expect(state.totalCount, 4);
      expect(state.hasMore, false);

      await controller.loadMore(request);
      expect(repository.fetchSongsCallCount(request), 2);
    },
  );

  test('loadMore failure keeps songs and retries the same page', () async {
    final repository = _ControlledPlaylistDetailRepository();
    final container = ProviderContainer(
      overrides: [
        playlistDetailRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    const request = PlaylistDetailRequest(
      id: 'playlist-1',
      platform: 'qq',
      title: '测试歌单',
    );
    final provider = playlistDetailControllerProvider(request.cacheKey);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(provider.notifier);
    final loading = controller.initialize(request);

    repository.completeInfo(request);
    repository.completeSongs(
      request,
      songs: <SongInfo>[_song('song-1')],
      pageIndex: 1,
      pageSize: 300,
      totalCount: 2,
      hasMore: true,
    );
    await loading;

    final loadingMore = controller.loadMore(request);
    repository.failSongs(request);
    await loadingMore;

    expect(container.read(provider).songs.single.id, 'song-1');
    expect(container.read(provider).loadMoreErrorMessage, contains('failed'));

    final retrying = controller.loadMore(request);
    expect(repository.lastSongsCall(request).pageIndex, 2);
    expect(repository.lastSongsCall(request).pageSize, 300);
    repository.completeSongs(
      request,
      songs: <SongInfo>[_song('song-2')],
      pageIndex: 2,
      pageSize: 300,
      totalCount: 2,
      hasMore: false,
    );
    await retrying;

    expect(container.read(provider).songs, hasLength(2));
    expect(container.read(provider).loadMoreErrorMessage, isNull);
  });

  test('late songs from a failed load cannot overwrite retry result', () async {
    final repository = _ControlledPlaylistDetailRepository();
    final container = ProviderContainer(
      overrides: [
        playlistDetailRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    const request = PlaylistDetailRequest(
      id: 'playlist-1',
      platform: 'qq',
      title: '测试歌单',
    );
    final provider = playlistDetailControllerProvider(request.cacheKey);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(provider.notifier);
    final initialLoading = controller.initialize(request);

    repository.failInfo(request);
    await container.pump();
    expect(container.read(provider).errorMessage, contains('info failed'));

    final retrying = controller.retry(request);
    repository.completeInfo(request);
    repository.completeSongs(request, songs: <SongInfo>[_song('new-song')]);
    await retrying;

    repository.completeSongsAt(
      request,
      0,
      songs: <SongInfo>[_song('old-song')],
    );
    await initialLoading;

    expect(container.read(provider).songs.single.id, 'new-song');
  });
}

class _ControlledPlaylistDetailRepository implements PlaylistDetailRepository {
  final Map<String, List<Completer<PlaylistInfo>>> _infoCompleters = {};
  final Map<String, List<_SongsCall>> _songCalls = {};

  @override
  Future<PlaylistInfo> fetchInfo(PlaylistDetailRequest request) {
    final completer = Completer<PlaylistInfo>();
    (_infoCompleters[request.cacheKey] ??= <Completer<PlaylistInfo>>[]).add(
      completer,
    );
    return completer.future;
  }

  @override
  Future<PlaylistDetailSongsPageResult> fetchSongs(
    PlaylistDetailRequest request, {
    int pageIndex = 1,
    int pageSize = playlistDetailSongsPageSize,
  }) {
    final call = _SongsCall(
      pageIndex: pageIndex,
      pageSize: pageSize,
      completer: Completer<PlaylistDetailSongsPageResult>(),
    );
    (_songCalls[request.cacheKey] ??= <_SongsCall>[]).add(call);
    return call.completer.future;
  }

  int fetchInfoCallCount(PlaylistDetailRequest request) {
    return _infoCompleters[request.cacheKey]?.length ?? 0;
  }

  int fetchSongsCallCount(PlaylistDetailRequest request) {
    return _songCalls[request.cacheKey]?.length ?? 0;
  }

  _SongsCall lastSongsCall(PlaylistDetailRequest request) {
    return _songCalls[request.cacheKey]!.last;
  }

  void completeInfo(PlaylistDetailRequest request) {
    _infoCompleters[request.cacheKey]!.last.complete(_infoFor(request));
  }

  void failInfo(PlaylistDetailRequest request) {
    _infoCompleters[request.cacheKey]!.last.completeError(
      Exception('info failed'),
    );
  }

  void completeSongs(
    PlaylistDetailRequest request, {
    List<SongInfo> songs = const <SongInfo>[],
    int? pageIndex,
    int? pageSize,
    int? totalCount,
    bool hasMore = false,
  }) {
    final call = lastSongsCall(request);
    call.completer.complete(
      PlaylistDetailSongsPageResult(
        songs: songs,
        pageIndex: pageIndex ?? call.pageIndex,
        pageSize: pageSize ?? call.pageSize,
        totalCount: totalCount ?? songs.length,
        hasMore: hasMore,
      ),
    );
  }

  void completeSongsAt(
    PlaylistDetailRequest request,
    int index, {
    required List<SongInfo> songs,
  }) {
    final call = _songCalls[request.cacheKey]![index];
    call.completer.complete(
      PlaylistDetailSongsPageResult(
        songs: songs,
        pageIndex: call.pageIndex,
        pageSize: call.pageSize,
        totalCount: songs.length,
        hasMore: false,
      ),
    );
  }

  void failSongs(PlaylistDetailRequest request) {
    lastSongsCall(request).completer.completeError(Exception('songs failed'));
  }
}

class _SongsCall {
  const _SongsCall({
    required this.pageIndex,
    required this.pageSize,
    required this.completer,
  });

  final int pageIndex;
  final int pageSize;
  final Completer<PlaylistDetailSongsPageResult> completer;
}

PlaylistInfo _infoFor(PlaylistDetailRequest request) {
  return PlaylistInfo(
    name: request.title,
    id: request.id,
    cover: '',
    creator: '',
    songCount: '0',
    playCount: '0',
    songs: const <SongInfo>[],
    platform: request.platform,
    description: '',
  );
}

SongInfo _song([String id = 'song-1', String platform = 'qq']) {
  return SongInfo(
    name: '测试歌曲',
    subtitle: '',
    id: id,
    duration: 180,
    mvId: '',
    album: SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
    artists: <SongInfoArtistInfo>[],
    links: <LinkInfo>[],
    platform: platform,
    cover: '',
  );
}
