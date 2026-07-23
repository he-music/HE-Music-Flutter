import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/he_music_models.dart';
import '../../../playlist/domain/entities/playlist_detail_state.dart';
import '../../data/providers/user_playlist_detail_providers.dart';
import '../../domain/entities/user_playlist_detail_request.dart';
import '../../domain/repositories/user_playlist_detail_repository.dart';
import '../providers/favorite_song_status_providers.dart';

class UserPlaylistDetailController extends Notifier<PlaylistDetailState> {
  String _lastRequestKey = '';
  int _infoRequestVersion = 0;
  int _songsRequestVersion = 0;

  @override
  PlaylistDetailState build() {
    return PlaylistDetailState.initial;
  }

  Future<void> initialize(UserPlaylistDetailRequest request) async {
    if (_lastRequestKey == request.cacheKey && state.content != null) {
      return;
    }
    _lastRequestKey = request.cacheKey;
    await _load(request);
  }

  Future<void> refresh(UserPlaylistDetailRequest request) async {
    _lastRequestKey = request.cacheKey;
    await _load(request);
  }

  Future<void> retry(UserPlaylistDetailRequest request) async {
    await _load(request);
  }

  Future<void> retrySongs(UserPlaylistDetailRequest request) async {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(songsLoading: true, clearSongsError: true);
    final repository = _repository;
    final requestVersion = ++_songsRequestVersion;
    await _loadSongs(repository, request, requestVersion);
  }

  Future<void> updatePlaylist({
    required UserPlaylistDetailRequest request,
    required String name,
    required String cover,
    required String description,
  }) async {
    await _repository.updatePlaylist(
      id: request.id,
      name: name,
      cover: cover,
      description: description,
    );
    if (!ref.mounted) {
      return;
    }
    await _load(request);
  }

  Future<void> deletePlaylist(String id) {
    return _repository.deletePlaylist(id);
  }

  /// 从自建歌单中移除歌曲，成功后重新拉取详情
  Future<void> removeSongs({
    required UserPlaylistDetailRequest request,
    required List<IdPlatformInfo> songs,
    bool isDefaultPlaylist = false,
  }) async {
    final favoriteStatus = isDefaultPlaylist
        ? ref.read(favoriteSongStatusProvider.notifier)
        : null;
    await _repository.removeSongs(playlistId: request.id, songs: songs);
    if (favoriteStatus != null) {
      for (final song in songs) {
        favoriteStatus.removeSong(songId: song.id, platform: song.platform);
      }
    }
    if (!ref.mounted) {
      return;
    }
    await _load(request);
  }

  Future<void> _load(UserPlaylistDetailRequest request) async {
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
    UserPlaylistDetailRepository repository,
    UserPlaylistDetailRequest request,
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
    UserPlaylistDetailRepository repository,
    UserPlaylistDetailRequest request,
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

  UserPlaylistDetailRepository get _repository {
    return ref.read(userPlaylistDetailRepositoryProvider);
  }
}
