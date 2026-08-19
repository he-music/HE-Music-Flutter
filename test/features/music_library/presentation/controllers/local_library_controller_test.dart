import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/music_library/domain/entities/local_song.dart';
import 'package:he_music_flutter/features/music_library/domain/repositories/local_music_repository.dart';
import 'package:he_music_flutter/features/music_library/presentation/controllers/local_library_controller.dart';
import 'package:he_music_flutter/features/music_library/presentation/providers/local_library_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('首次加载 50 首，加载更多后包含第 51 首', () async {
    final repository = _FakeLocalMusicRepository(_songs(51));
    final container = _createContainer(repository);
    addTearDown(container.dispose);
    final controller = await _initializeController(container);

    controller.startWatchingSongs();
    await _flush(container);

    expect(container.read(localLibraryControllerProvider).value, hasLength(50));
    expect(controller.hasMore, isTrue);

    await controller.loadMore();
    await _flush(container);

    final songs = container.read(localLibraryControllerProvider).value!;
    expect(songs, hasLength(51));
    expect(songs.last.id, 'song-051');
    expect(controller.hasMore, isFalse);
    expect(repository.calls.map((call) => call.limit), [51, 101]);
  });

  test('加载更多进行中会忽略重复请求', () async {
    final pendingPage = StreamController<List<LocalSong>>();
    final repository = _FakeLocalMusicRepository(
      _songs(80),
      streamForCall: (call, callIndex, songs) {
        if (callIndex == 1) {
          return pendingPage.stream;
        }
        return Stream<List<LocalSong>>.value(songs.take(call.limit).toList());
      },
    );
    final container = _createContainer(repository);
    addTearDown(() async {
      await pendingPage.close();
      container.dispose();
    });
    final controller = await _initializeController(container);
    controller.startWatchingSongs();
    await _flush(container);

    await controller.loadMore();
    await controller.loadMore();

    expect(repository.calls, hasLength(2));
    expect(controller.loadingMore, isTrue);

    pendingPage.add(_songs(80));
    await _flush(container);

    expect(controller.loadingMore, isFalse);
    expect(container.read(localLibraryControllerProvider).value, hasLength(80));
  });

  test('加载更多失败后重试仍请求同一扩展范围', () async {
    final repository = _FakeLocalMusicRepository(
      _songs(80),
      streamForCall: (call, callIndex, songs) {
        if (callIndex == 1) {
          return Stream<List<LocalSong>>.error(StateError('加载更多失败'));
        }
        return Stream<List<LocalSong>>.value(songs);
      },
    );
    final container = _createContainer(repository);
    addTearDown(container.dispose);
    final controller = await _initializeController(container);
    controller.startWatchingSongs();
    await _flush(container);

    await controller.loadMore();
    await _flush(container);

    expect(controller.loadingMore, isFalse);
    expect(controller.loadMoreErrorMessage, contains('加载更多失败'));
    expect(container.read(localLibraryControllerProvider).value, hasLength(50));

    await controller.loadMore();
    await _flush(container);

    expect(repository.calls.map((call) => call.limit), [51, 101, 101]);
    expect(controller.loadMoreErrorMessage, isNull);
    expect(container.read(localLibraryControllerProvider).value, hasLength(80));
  });

  test('加载更多期间切换排序失败会进入主错误状态', () async {
    final pendingPage = StreamController<List<LocalSong>>();
    final repository = _FakeLocalMusicRepository(
      _songs(80),
      streamForCall: (call, callIndex, songs) {
        if (callIndex == 1) {
          return pendingPage.stream;
        }
        if (callIndex == 2) {
          return Stream<List<LocalSong>>.error(StateError('排序失败'));
        }
        return Stream<List<LocalSong>>.value(songs);
      },
    );
    final container = _createContainer(repository);
    addTearDown(() async {
      await pendingPage.close();
      container.dispose();
    });
    final controller = await _initializeController(container);
    controller.startWatchingSongs();
    await _flush(container);
    await controller.loadMore();

    controller.changeSortBy(SongSortBy.artist);
    await _flush(container);

    final state = container.read(localLibraryControllerProvider);
    expect(state.hasError, isTrue);
    expect('${state.error}', contains('排序失败'));
    expect(controller.loadingMore, isFalse);
    expect(controller.loadMoreErrorMessage, isNull);
  });

  test('搜索、排序和退出搜索都会重置分页', () async {
    final repository = _FakeLocalMusicRepository(
      _songs(120, titlePrefix: '匹配'),
    );
    final container = _createContainer(repository);
    addTearDown(container.dispose);
    final controller = await _initializeController(container);
    controller.startWatchingSongs();
    await _flush(container);
    await controller.loadMore();
    await _flush(container);
    expect(
      container.read(localLibraryControllerProvider).value,
      hasLength(100),
    );

    controller.updateSearchQuery('匹配');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await _flush(container);

    expect(repository.calls.last.searchQuery, '匹配');
    expect(repository.calls.last.limit, 51);
    expect(container.read(localLibraryControllerProvider).value, hasLength(50));

    await controller.loadMore();
    await _flush(container);
    controller.changeSortBy(SongSortBy.artist);
    await _flush(container);

    expect(repository.calls.last.searchQuery, '匹配');
    expect(repository.calls.last.sortBy, 'artist');
    expect(repository.calls.last.limit, 51);
    expect(container.read(localLibraryControllerProvider).value, hasLength(50));

    controller.toggleSearch();
    await _flush(container);

    expect(repository.calls.last.searchQuery, isNull);
    expect(repository.calls.last.limit, 51);
    expect(container.read(localLibraryControllerProvider).value, hasLength(50));
  });
}

ProviderContainer _createContainer(LocalMusicRepository repository) {
  return ProviderContainer(
    overrides: [localMusicRepositoryProvider.overrideWithValue(repository)],
  );
}

Future<LocalLibraryController> _initializeController(
  ProviderContainer container,
) async {
  await container.read(localLibraryControllerProvider.future);
  return container.read(localLibraryControllerProvider.notifier);
}

Future<void> _flush(ProviderContainer container) async {
  await Future<void>.delayed(Duration.zero);
  await container.pump();
  await Future<void>.delayed(Duration.zero);
}

List<LocalSong> _songs(int count, {String titlePrefix = '歌曲'}) {
  return List<LocalSong>.generate(count, (index) {
    final number = '${index + 1}'.padLeft(3, '0');
    return LocalSong(
      id: 'song-$number',
      title: '$titlePrefix $number',
      filePath: '/music/$number.mp3',
      artist: '歌手 ${count - index}',
      album: '专辑',
      duration: const Duration(minutes: 3),
      mimeType: 'audio/mpeg',
      size: 1024,
    );
  });
}

typedef _StreamForCall =
    Stream<List<LocalSong>> Function(
      _WatchSongsCall call,
      int callIndex,
      List<LocalSong> songs,
    );

class _FakeLocalMusicRepository implements LocalMusicRepository {
  _FakeLocalMusicRepository(this.songs, {this.streamForCall});

  final List<LocalSong> songs;
  final _StreamForCall? streamForCall;
  final List<_WatchSongsCall> calls = <_WatchSongsCall>[];

  @override
  Stream<List<LocalSong>> watchSongs({
    String? searchQuery,
    String sortBy = 'title',
    bool ascending = true,
    int offset = 0,
    int limit = 50,
  }) {
    final call = _WatchSongsCall(
      searchQuery: searchQuery,
      sortBy: sortBy,
      ascending: ascending,
      offset: offset,
      limit: limit,
    );
    calls.add(call);
    final filtered = songs
        .where(
          (song) =>
              searchQuery == null ||
              song.title.contains(searchQuery) ||
              song.artist.contains(searchQuery) ||
              song.album.contains(searchQuery),
        )
        .toList();
    filtered.sort((left, right) {
      final comparison = switch (sortBy) {
        'artist' => left.artist.compareTo(right.artist),
        'album' => left.album.compareTo(right.album),
        _ => left.title.compareTo(right.title),
      };
      return ascending ? comparison : -comparison;
    });
    final page = filtered.skip(offset).take(limit).toList();
    return streamForCall?.call(call, calls.length - 1, page) ??
        Stream<List<LocalSong>>.value(page);
  }

  @override
  Future<void> clearLibrary() async {}

  @override
  Future<void> incrementPlayCount(String songId) async {}

  @override
  Future<void> markFileMissing(String songId) async {}

  @override
  Future<void> markMetadataEdited(String songId) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<List<LocalSong>> scanSongs() async => songs;

  @override
  Stream<List<AlbumGroup>> watchAlbums() => const Stream.empty();

  @override
  Stream<List<ArtistGroup>> watchArtists() => const Stream.empty();

  @override
  Stream<List<GenreGroup>> watchGenres() => const Stream.empty();

  @override
  Stream<List<LocalSong>> watchSongsByAlbum(String albumName) =>
      const Stream.empty();

  @override
  Stream<List<LocalSong>> watchSongsByArtist(String artistName) =>
      const Stream.empty();
}

class _WatchSongsCall {
  const _WatchSongsCall({
    required this.searchQuery,
    required this.sortBy,
    required this.ascending,
    required this.offset,
    required this.limit,
  });

  final String? searchQuery;
  final String sortBy;
  final bool ascending;
  final int offset;
  final int limit;
}
