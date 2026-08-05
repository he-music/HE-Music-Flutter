import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/home_page_providers.dart';
import '../../domain/entities/recommend_song_list_request.dart';
import '../../domain/entities/recommend_song_list_state.dart';

class RecommendSongListController extends Notifier<RecommendSongListState> {
  String _lastRequestKey = '';
  int _requestVersion = 0;

  @override
  RecommendSongListState build() {
    return RecommendSongListState.initial;
  }

  Future<void> initialize(RecommendSongListRequest request) async {
    if (_lastRequestKey == request.cacheKey && state.info != null) {
      return;
    }
    _lastRequestKey = request.cacheKey;
    await _load(request);
  }

  Future<void> retry(RecommendSongListRequest request) {
    return _load(request);
  }

  Future<void> _load(RecommendSongListRequest request) async {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    final requestVersion = ++_requestVersion;
    try {
      final info = await ref
          .read(homePageApiClientProvider)
          .fetchRecommendSongList(request);
      if (!ref.mounted ||
          requestVersion != _requestVersion ||
          request.cacheKey != _lastRequestKey) {
        return;
      }
      state = state.copyWith(loading: false, info: info, clearError: true);
    } catch (error) {
      if (!ref.mounted ||
          requestVersion != _requestVersion ||
          request.cacheKey != _lastRequestKey) {
        return;
      }
      state = state.copyWith(loading: false, errorMessage: '$error');
    }
  }
}
