import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_request.dart';
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
  final Map<String, List<Completer<List<SongInfo>>>> _songCompleters = {};

  @override
  Future<PlaylistInfo> fetchInfo(PlaylistDetailRequest request) {
    final completer = Completer<PlaylistInfo>();
    (_infoCompleters[request.cacheKey] ??= <Completer<PlaylistInfo>>[]).add(
      completer,
    );
    return completer.future;
  }

  @override
  Future<List<SongInfo>> fetchSongs(PlaylistDetailRequest request) {
    final completer = Completer<List<SongInfo>>();
    (_songCompleters[request.cacheKey] ??= <Completer<List<SongInfo>>>[]).add(
      completer,
    );
    return completer.future;
  }

  int fetchInfoCallCount(PlaylistDetailRequest request) {
    return _infoCompleters[request.cacheKey]?.length ?? 0;
  }

  int fetchSongsCallCount(PlaylistDetailRequest request) {
    return _songCompleters[request.cacheKey]?.length ?? 0;
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
  }) {
    _songCompleters[request.cacheKey]!.last.complete(songs);
  }

  void completeSongsAt(
    PlaylistDetailRequest request,
    int index, {
    required List<SongInfo> songs,
  }) {
    _songCompleters[request.cacheKey]![index].complete(songs);
  }

  void failSongs(PlaylistDetailRequest request) {
    _songCompleters[request.cacheKey]!.last.completeError(
      Exception('songs failed'),
    );
  }
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

SongInfo _song([String id = 'song-1']) {
  return SongInfo(
    name: '测试歌曲',
    subtitle: '',
    id: id,
    duration: 180,
    mvId: '',
    album: SongInfoAlbumInfo(name: '测试专辑', id: 'album-1'),
    artists: <SongInfoArtistInfo>[],
    links: <LinkInfo>[],
    platform: 'qq',
    cover: '',
  );
}
