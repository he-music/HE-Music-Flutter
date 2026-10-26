import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/my/domain/entities/favorite_song_status_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/user_playlist_detail_request.dart';
import 'package:he_music_flutter/features/my/domain/repositories/user_playlist_detail_repository.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/features/my/presentation/providers/user_playlist_detail_providers.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_songs_page_result.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/utils/favorite_song_key.dart';

const _request = UserPlaylistDetailRequest(id: 'playlist-1', title: 'T');
final _provider = userPlaylistDetailControllerProvider(_request.cacheKey);

void main() {
  test('removeSongs 从默认歌单移除歌曲后同步喜欢歌曲状态', () async {
    final repository = _FakeUserPlaylistDetailRepository(isDefault: true);
    final container = _createContainer(repository);
    final controller = container.read(_provider.notifier);

    await controller.removeSongs(
      request: _request,
      songs: const <IdPlatformInfo>[
        IdPlatformInfo(id: 'song-1', platform: 'qq'),
      ],
      isDefaultPlaylist: true,
    );

    expect(
      container.read(favoriteSongStatusProvider).songKeys,
      isNot(contains(buildFavoriteSongKey(songId: 'song-1', platform: 'qq'))),
    );
  });

  for (final isDefault in [false, true]) {
    test('loadMore 支持超过1000首的后续页并按平台和id去重 default=$isDefault', () async {
      final repository = _FakeUserPlaylistDetailRepository(
        isDefault: isDefault,
      );
      repository.onSongs = (request, pageIndex, pageSize) async =>
          pageIndex == 1
          ? _page([_song('a'), _song('same')], hasMore: true)
          : _page([
              _song('same'),
              _song('same', platform: 'netease'),
              _song('b'),
              _song('b'),
            ], pageIndex: 2);
      final container = _createContainer(repository);
      final controller = container.read(_provider.notifier);

      await controller.initialize(_request);
      expect(container.read(_provider).totalCount, 1002);
      await controller.loadMore(_request);
      await controller.loadMore(_request);

      final state = container.read(_provider);
      expect(repository.songRequests, [
        ('playlist-1', 1, playlistDetailSongsPageSize),
        ('playlist-1', 2, playlistDetailSongsPageSize),
      ]);
      expect(state.songs.map((song) => '${song.platform}:${song.id}'), [
        'qq:a',
        'qq:same',
        'netease:same',
        'qq:b',
      ]);
      expect(state.pageIndex, 2);
      expect(state.hasMore, isFalse);
      expect(state.content!.isDefault, isDefault);
    });
  }

  test('loadMore 失败保留旧歌曲和页码并重试同一页', () async {
    final repository = _FakeUserPlaylistDetailRepository();
    var fail = true;
    repository.onSongs = (request, pageIndex, pageSize) async {
      if (pageIndex == 1) return _page([_song('a')], hasMore: true);
      if (fail) throw Exception('page failed');
      return _page([_song('b')], pageIndex: 2);
    };
    final container = _createContainer(repository);
    final controller = container.read(_provider.notifier);
    await controller.initialize(_request);
    await controller.loadMore(_request);

    var state = container.read(_provider);
    expect(state.songs.single.id, 'a');
    expect(state.pageIndex, 1);
    expect(state.hasMore, isTrue);
    expect(state.loadingMore, isFalse);
    expect(state.loadMoreErrorMessage, contains('page failed'));
    expect(state.songsErrorMessage, isNull);
    fail = false;
    await controller.loadMore(_request);
    state = container.read(_provider);
    expect(state.songs.map((song) => song.id), ['a', 'b']);
    expect(state.loadMoreErrorMessage, isNull);
    expect(repository.songRequests.map((request) => request.$2), [1, 2, 2]);
  });

  test('loadMore 忽略重复调用和不匹配歌单', () async {
    final pending = Completer<PlaylistDetailSongsPageResult>();
    final repository = _FakeUserPlaylistDetailRepository();
    repository.onSongs = (request, pageIndex, pageSize) async =>
        pageIndex == 1 ? _page([_song('a')], hasMore: true) : pending.future;
    final container = _createContainer(repository);
    final controller = container.read(_provider.notifier);
    await controller.initialize(_request);
    await controller.loadMore(
      const UserPlaylistDetailRequest(id: 'other', title: ''),
    );
    final loading = controller.loadMore(_request);
    await controller.loadMore(_request);
    expect(repository.songRequests.length, 2);
    expect(container.read(_provider).loadingMore, isTrue);
    pending.complete(_page([_song('b')], pageIndex: 2));
    await loading;
  });

  for (final fails in [false, true]) {
    test('refresh 后忽略旧加载更多的${fails ? '失败' : '成功'}响应', () async {
      final pending = Completer<PlaylistDetailSongsPageResult>();
      final repository = _FakeUserPlaylistDetailRepository();
      var firstPageCalls = 0;
      repository.onSongs = (request, pageIndex, pageSize) async {
        if (pageIndex == 2) return pending.future;
        firstPageCalls++;
        return _page([
          _song(firstPageCalls == 1 ? 'old' : 'fresh'),
        ], hasMore: true);
      };
      final container = _createContainer(repository);
      final controller = container.read(_provider.notifier);
      await controller.initialize(_request);
      final loading = controller.loadMore(_request);
      await controller.refresh(_request);
      if (fails) {
        pending.completeError(Exception('stale failure'));
      } else {
        pending.complete(_page([_song('stale')], pageIndex: 2));
      }
      await loading;

      final state = container.read(_provider);
      expect(state.songs.single.id, 'fresh');
      expect(state.pageIndex, 1);
      expect(state.loadingMore, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.loadMoreErrorMessage, isNull);
      expect(repository.songRequests.map((request) => request.$2), [1, 2, 1]);
    });
  }

  test('retrySongs 在首屏失败后从第一页重试并恢复分页', () async {
    final repository = _FakeUserPlaylistDetailRepository();
    var fail = true;
    repository.onSongs = (request, pageIndex, pageSize) async {
      if (fail) throw Exception('first page failed');
      return _page([_song('fresh')], hasMore: true);
    };
    final container = _createContainer(repository);
    final controller = container.read(_provider.notifier);
    await controller.initialize(_request);
    expect(container.read(_provider).songsErrorMessage, isNotNull);
    fail = false;
    await controller.retrySongs(_request);
    final state = container.read(_provider);
    expect(state.songs.single.id, 'fresh');
    expect(state.pageIndex, 1);
    expect(state.hasMore, isTrue);
    expect(state.songsErrorMessage, isNull);
    expect(repository.songRequests.map((request) => request.$2), [1, 1]);
  });

  test('removeSongs 回刷重置分页且旧分页不能恢复已删除歌曲', () async {
    final pending = Completer<PlaylistDetailSongsPageResult>();
    final repository = _FakeUserPlaylistDetailRepository();
    var firstPageCalls = 0;
    repository.onSongs = (request, pageIndex, pageSize) async {
      if (pageIndex == 2) return pending.future;
      firstPageCalls++;
      return _page([
        _song(firstPageCalls == 1 ? 'removed' : 'remaining'),
      ], hasMore: true);
    };
    final container = _createContainer(repository);
    final controller = container.read(_provider.notifier);
    await controller.initialize(_request);
    final loading = controller.loadMore(_request);
    await controller.removeSongs(
      request: _request,
      songs: const [IdPlatformInfo(id: 'removed', platform: 'qq')],
    );
    pending.complete(_page([_song('removed')], pageIndex: 2));
    await loading;
    final state = container.read(_provider);
    expect(state.songs.single.id, 'remaining');
    expect(state.pageIndex, 1);
    expect(state.hasMore, isTrue);
    expect(state.loadingMore, isFalse);
    expect(repository.songRequests.map((request) => request.$2), [1, 2, 1]);
  });

  test('删除等待期间refresh的旧首屏响应不能覆盖删除回刷', () async {
    final pendingRefresh = Completer<PlaylistDetailSongsPageResult>();
    final removal = Completer<void>();
    final repository = _FakeUserPlaylistDetailRepository()
      ..removal = removal.future;
    var firstPageCalls = 0;
    repository.onSongs = (request, pageIndex, pageSize) async {
      firstPageCalls++;
      if (firstPageCalls == 2) return pendingRefresh.future;
      return _page([_song(firstPageCalls == 1 ? 'old' : 'after-delete')]);
    };
    final container = _createContainer(repository);
    final controller = container.read(_provider.notifier);
    await controller.initialize(_request);
    final deleting = controller.removeSongs(request: _request, songs: const []);
    final refreshing = controller.refresh(_request);
    removal.complete();
    await deleting;
    pendingRefresh.complete(_page([_song('stale-refresh')]));
    await refreshing;
    expect(container.read(_provider).songs.single.id, 'after-delete');
    expect(repository.songRequests.map((request) => request.$2), [1, 1, 1]);
  });

  test('删除等待期间切换歌单后不触发旧歌单回刷', () async {
    final removal = Completer<void>();
    final repository = _FakeUserPlaylistDetailRepository()
      ..removal = removal.future;
    repository.onSongs = (request, pageIndex, pageSize) async =>
        _page([_song(request.id)]);
    final container = _createContainer(repository);
    final controller = container.read(_provider.notifier);
    await controller.initialize(_request);
    final deleting = controller.removeSongs(request: _request, songs: const []);
    const other = UserPlaylistDetailRequest(id: 'other', title: 'Other');
    await controller.refresh(other);
    removal.complete();
    await deleting;
    expect(container.read(_provider).info!.id, 'other');
    expect(container.read(_provider).songs.single.id, 'other');
    expect(repository.songRequests.map((request) => request.$1), [
      'playlist-1',
      'other',
    ]);
  });
}

ProviderContainer _createContainer(
  _FakeUserPlaylistDetailRepository repository,
) {
  final container = ProviderContainer(
    overrides: [
      userPlaylistDetailRepositoryProvider.overrideWithValue(repository),
      favoriteSongStatusProvider.overrideWith(_TestFavoriteSongStatus.new),
    ],
  );
  addTearDown(container.dispose);
  final subscription = container.listen(_provider, (_, _) {});
  addTearDown(subscription.close);
  return container;
}

PlaylistDetailSongsPageResult _page(
  List<SongInfo> songs, {
  int pageIndex = 1,
  bool hasMore = false,
}) => PlaylistDetailSongsPageResult(
  songs: songs,
  pageIndex: pageIndex,
  pageSize: playlistDetailSongsPageSize,
  totalCount: 1002,
  hasMore: hasMore,
);

SongInfo _song(String id, {String platform = 'qq'}) =>
    SongInfo.fromMap({'id': id, 'name': id, 'platform': platform});

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
  _FakeUserPlaylistDetailRepository({this.isDefault = false});

  final bool isDefault;
  final songRequests = <(String, int, int)>[];
  Future<PlaylistDetailSongsPageResult> Function(
    UserPlaylistDetailRequest,
    int,
    int,
  )?
  onSongs;
  Future<void>? removal;

  @override
  Future<PlaylistInfo> fetchInfo(UserPlaylistDetailRequest request) async {
    return PlaylistInfo(
      name: '测试歌单',
      id: request.id,
      cover: '',
      creator: 'me',
      songCount: '1002',
      playCount: '0',
      songs: const <SongInfo>[],
      platform: 'user',
      description: '',
      isDefault: isDefault,
    );
  }

  @override
  Future<PlaylistDetailSongsPageResult> fetchSongs(
    UserPlaylistDetailRequest request, {
    int pageIndex = 1,
    int pageSize = playlistDetailSongsPageSize,
  }) async {
    songRequests.add((request.id, pageIndex, pageSize));
    return onSongs == null ? _page([]) : onSongs!(request, pageIndex, pageSize);
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
  }) async {
    await removal;
  }

  @override
  Future<void> updatePlaylist({
    required String id,
    required String name,
    required String cover,
    required String description,
  }) async {}
}
