import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/album_detail_request.dart';
import '../../domain/entities/album_detail_state.dart';
import '../../domain/repositories/album_detail_repository.dart';
import '../../data/providers/album_detail_providers.dart';

class AlbumDetailController extends Notifier<AlbumDetailState> {
  String _lastRequestKey = '';

  @override
  AlbumDetailState build() {
    return AlbumDetailState.initial;
  }

  Future<void> initialize(AlbumDetailRequest request) async {
    if (_lastRequestKey == request.cacheKey && state.content != null) {
      return;
    }
    _lastRequestKey = request.cacheKey;
    await _load(request);
  }

  Future<void> retry(AlbumDetailRequest request) async {
    await _load(request);
  }

  Future<void> _load(AlbumDetailRequest request) async {
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

  AlbumDetailRepository get _repository {
    return ref.read(albumDetailRepositoryProvider);
  }
}
