import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist_detail_request.dart';
import '../../domain/entities/playlist_detail_state.dart';
import '../../domain/repositories/playlist_detail_repository.dart';
import '../../data/providers/playlist_detail_providers.dart';

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
    state = state.copyWith(songsLoading: true, clearSongsError: true);
    final repository = _repository;
    final requestVersion = ++_songsRequestVersion;
    await _loadSongs(repository, request, requestVersion);
  }

  Future<void> _load(PlaylistDetailRequest request) async {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      loading: true,
      songsLoading: true,
      clearError: true,
      clearSongsError: true,
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
      final songs = await repository.fetchSongs(request);
      if (!ref.mounted || requestVersion != _songsRequestVersion) {
        return;
      }
      state = state.copyWith(
        songsLoading: false,
        songs: songs,
        clearSongsError: true,
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
}
