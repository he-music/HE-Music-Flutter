import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist_detail_request.dart';
import '../../domain/entities/playlist_detail_state.dart';
import '../../domain/repositories/playlist_detail_repository.dart';
import '../providers/playlist_detail_providers.dart';

class PlaylistDetailController extends Notifier<PlaylistDetailState> {
  String _lastRequestKey = '';

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

  Future<void> _load(PlaylistDetailRequest request) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final content = await _repository.fetchDetail(request);
      state = state.copyWith(
        loading: false,
        content: content,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(loading: false, errorMessage: '$error');
    }
  }

  PlaylistDetailRepository get _repository {
    return ref.read(playlistDetailRepositoryProvider);
  }
}
