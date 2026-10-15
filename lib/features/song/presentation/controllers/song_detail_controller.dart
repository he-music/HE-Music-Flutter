import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/song_detail_request.dart';
import '../../domain/entities/song_detail_state.dart';
import '../../domain/repositories/song_detail_repository.dart';
import '../../data/providers/song_detail_providers.dart';

class SongDetailController extends Notifier<SongDetailState> {
  String _lastRequestKey = '';
  int _requestRevision = 0;

  @override
  SongDetailState build() {
    return SongDetailState.initial;
  }

  Future<void> initialize(SongDetailRequest request) async {
    if (_lastRequestKey == request.cacheKey && state.content != null) {
      return;
    }
    _lastRequestKey = request.cacheKey;
    await _load(request);
  }

  Future<void> retry(SongDetailRequest request) async {
    await _load(request);
  }

  Future<void> _load(SongDetailRequest request) async {
    if (!ref.mounted) {
      return;
    }
    final revision = ++_requestRevision;
    _lastRequestKey = request.cacheKey;
    state = state.copyWith(loading: true, clearContent: true, clearError: true);
    try {
      final content = await _repository.fetchDetail(request);
      if (!ref.mounted || revision != _requestRevision) {
        return;
      }
      state = state.copyWith(
        loading: false,
        content: content,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted || revision != _requestRevision) {
        return;
      }
      state = state.copyWith(loading: false, errorMessage: '$error');
    }
  }

  SongDetailRepository get _repository {
    return ref.read(songDetailRepositoryProvider);
  }
}
