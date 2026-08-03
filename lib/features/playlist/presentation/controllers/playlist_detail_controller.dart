import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/id_platform_key.dart';
import '../../data/providers/playlist_detail_providers.dart';
import '../../domain/entities/playlist_detail_request.dart';
import '../../domain/entities/playlist_detail_song.dart';
import '../../domain/entities/playlist_detail_songs_page_result.dart';
import '../../domain/entities/playlist_detail_state.dart';
import '../../domain/repositories/playlist_detail_repository.dart';

class PlaylistDetailController extends Notifier<PlaylistDetailState> {
  String _lastRequestKey = '';
  int _infoRequestVersion = 0;
  int _songsRequestVersion = 0;

  @override
  PlaylistDetailState build() {
    return PlaylistDetailState.initial;
  }

  Future<void> initialize(PlaylistDetailRequest request) async {
    if (_lastRequestKey == request.cacheKey && state.content != null) {
      return;
    }
    _lastRequestKey = request.cacheKey;
    await _load(request);
  }

  Future<void> retry(PlaylistDetailRequest request) async {
    await _load(request);
  }

  Future<void> retrySongs(PlaylistDetailRequest request) async {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      songsLoading: true,
      loadingMore: false,
      pageIndex: 0,
      pageSize: playlistDetailSongsPageSize,
      totalCount: 0,
      hasMore: false,
      clearSongsError: true,
      clearLoadMoreError: true,
    );
    final repository = _repository;
    final requestVersion = ++_songsRequestVersion;
    await _loadSongs(repository, request, requestVersion);
  }

  Future<void> loadMore(PlaylistDetailRequest request) async {
    if (!ref.mounted ||
        _lastRequestKey != request.cacheKey ||
        state.songsLoading ||
        state.loadingMore ||
        !state.hasMore) {
      return;
    }
    final requestVersion = _songsRequestVersion;
    final nextPageIndex = state.pageIndex + 1;
    final pageSize = state.pageSize;
    state = state.copyWith(loadingMore: true, clearLoadMoreError: true);
    try {
      final result = await _repository.fetchSongs(
        request,
        pageIndex: nextPageIndex,
        pageSize: pageSize,
      );
      if (!ref.mounted || requestVersion != _songsRequestVersion) {
        return;
      }
      state = state.copyWith(
        loadingMore: false,
        songs: _appendUniqueSongs(state.songs, result.songs),
        pageIndex: result.pageIndex,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
        hasMore: result.hasMore,
        clearLoadMoreError: true,
      );
    } catch (error) {
      if (!ref.mounted || requestVersion != _songsRequestVersion) {
        return;
      }
      state = state.copyWith(
        loadingMore: false,
        loadMoreErrorMessage: '$error',
      );
    }
  }

  Future<void> _load(PlaylistDetailRequest request) async {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      loading: true,
      songsLoading: true,
      loadingMore: false,
      pageIndex: 0,
      pageSize: playlistDetailSongsPageSize,
      totalCount: 0,
      hasMore: false,
      clearError: true,
      clearSongsError: true,
      clearLoadMoreError: true,
    );
    final repository = _repository;
    final infoRequestVersion = ++_infoRequestVersion;
    final songsRequestVersion = ++_songsRequestVersion;
    await Future.wait<void>(<Future<void>>[
      _loadInfo(repository, request, infoRequestVersion),
      _loadSongs(repository, request, songsRequestVersion),
    ]);
  }

  Future<void> _loadInfo(
    PlaylistDetailRepository repository,
    PlaylistDetailRequest request,
    int requestVersion,
  ) async {
    try {
      final info = await repository.fetchInfo(request);
      if (!ref.mounted || requestVersion != _infoRequestVersion) {
        return;
      }
      state = state.copyWith(loading: false, info: info, clearError: true);
    } catch (error) {
      if (!ref.mounted || requestVersion != _infoRequestVersion) {
        return;
      }
      state = state.copyWith(loading: false, errorMessage: '$error');
    }
  }

  Future<void> _loadSongs(
    PlaylistDetailRepository repository,
    PlaylistDetailRequest request,
    int requestVersion,
  ) async {
    try {
      final result = await repository.fetchSongs(request);
      if (!ref.mounted || requestVersion != _songsRequestVersion) {
        return;
      }
      state = state.copyWith(
        songsLoading: false,
        songs: result.songs,
        pageIndex: result.pageIndex,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
        hasMore: result.hasMore,
        clearSongsError: true,
        clearLoadMoreError: true,
      );
    } catch (error) {
      if (!ref.mounted || requestVersion != _songsRequestVersion) {
        return;
      }
      state = state.copyWith(songsLoading: false, songsErrorMessage: '$error');
    }
  }

  PlaylistDetailRepository get _repository {
    return ref.read(playlistDetailRepositoryProvider);
  }

  List<PlaylistDetailSong> _appendUniqueSongs(
    List<PlaylistDetailSong> current,
    List<PlaylistDetailSong> incoming,
  ) {
    final keys = current
        .map((song) => buildIdPlatformKey(id: song.id, platform: song.platform))
        .toSet();
    final result = <PlaylistDetailSong>[...current];
    for (final song in incoming) {
      final key = buildIdPlatformKey(id: song.id, platform: song.platform);
      if (keys.add(key)) {
        result.add(song);
      }
    }
    return List<PlaylistDetailSong>.unmodifiable(result);
  }
}
