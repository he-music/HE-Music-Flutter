import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/video_detail_request.dart';
import '../../domain/entities/video_detail_state.dart';
import '../../domain/repositories/video_detail_repository.dart';
import '../providers/video_detail_providers.dart';

class VideoDetailController extends Notifier<VideoDetailState> {
  String _lastRequestKey = '';

  @override
  VideoDetailState build() {
    return VideoDetailState.initial;
  }

  Future<void> initialize(VideoDetailRequest request) async {
    if (_lastRequestKey == request.cacheKey && state.content != null) {
      return;
    }
    _lastRequestKey = request.cacheKey;
    await _load(request);
  }

  Future<void> retry(VideoDetailRequest request) async {
    await _load(request);
  }

  Future<void> _load(VideoDetailRequest request) async {
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

  VideoDetailRepository get _repository {
    return ref.read(videoDetailRepositoryProvider);
  }
}
