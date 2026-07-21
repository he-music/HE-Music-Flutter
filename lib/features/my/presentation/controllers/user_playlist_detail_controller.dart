import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/he_music_models.dart';
import '../../../playlist/domain/entities/playlist_detail_state.dart';
import '../../data/providers/user_playlist_detail_providers.dart';
import '../../domain/entities/user_playlist_detail_request.dart';
import '../../domain/repositories/user_playlist_detail_repository.dart';
import '../providers/favorite_song_status_providers.dart';

class UserPlaylistDetailController extends Notifier<PlaylistDetailState> {
  String _lastRequestKey = '';

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
    state = state.copyWith(loading: true, clearError: true);
    try {
      final content = await _repository.fetchDetail(request);
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        loading: false,
        content: content,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(loading: false, errorMessage: '$error');
    }
  }

  UserPlaylistDetailRepository get _repository {
    return ref.read(userPlaylistDetailRepositoryProvider);
  }
}
