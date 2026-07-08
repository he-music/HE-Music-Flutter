import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/artist_detail_request.dart';
import '../../domain/entities/artist_detail_state.dart';
import '../../domain/repositories/artist_detail_repository.dart';
import '../providers/artist_detail_providers.dart';

class ArtistDetailController extends Notifier<ArtistDetailState> {
  String _lastRequestKey = '';

  @override
  ArtistDetailState build() {
    return ArtistDetailState.initial;
  }

  Future<void> initialize(ArtistDetailRequest request) async {
    if (_lastRequestKey == request.cacheKey && state.content != null) {
      return;
    }
    _lastRequestKey = request.cacheKey;
    await _load(request);
  }

  Future<void> retry(ArtistDetailRequest request) async {
    await _load(request);
  }

  Future<void> _load(ArtistDetailRequest request) async {
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

  ArtistDetailRepository get _repository {
    return ref.read(artistDetailRepositoryProvider);
  }
}
