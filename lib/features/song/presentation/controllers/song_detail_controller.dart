import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/entities/song_detail_request.dart';
import '../../domain/entities/song_detail_state.dart';
import '../../domain/repositories/song_detail_repository.dart';
import '../../data/providers/song_detail_providers.dart';

class SongDetailController extends Notifier<SongDetailState> {
  String _lastRequestKey = '';

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
    state = state.copyWith(
      loading: true,
      relationsLoading: false,
      clearContent: true,
      clearError: true,
      clearRelationsError: true,
      clearRelations: true,
    );
    try {
      final content = await _repository.fetchDetail(request);
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        loading: false,
        content: content,
        relationsLoading: false,
        clearError: true,
        clearRelationsError: true,
      );
      final supportsSongRelations = await _supportsSongRelations(
        request.platform,
      );
      if (!ref.mounted) {
        return;
      }
      if (!supportsSongRelations) {
        return;
      }
      state = state.copyWith(relationsLoading: true);
      try {
        final relations = await _repository.fetchRelations(request);
        if (!ref.mounted) {
          return;
        }
        state = state.copyWith(
          relationsLoading: false,
          relations: relations,
          clearRelationsError: true,
        );
      } catch (error) {
        if (!ref.mounted) {
          return;
        }
        state = state.copyWith(
          relationsLoading: false,
          relationsErrorMessage: '$error',
        );
      }
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        loading: false,
        relationsLoading: false,
        errorMessage: '$error',
      );
    }
  }

  SongDetailRepository get _repository {
    return ref.read(songDetailRepositoryProvider);
  }

  Future<bool> _supportsSongRelations(String platformId) async {
    List<OnlinePlatform>? platforms;
    try {
      platforms = await ref.read(onlinePlatformsProvider.future);
    } catch (_) {
      platforms = ref.read(onlinePlatformsProvider).value;
    }
    if (platforms == null) {
      return false;
    }
    final platform = platforms
        .where((item) => item.id == platformId)
        .firstOrNull;
    if (platform == null) {
      return false;
    }
    // 仅在确认平台可用且支持“歌曲相关”时请求，能力未知时不展示加载占位。
    return platform.available &&
        platform.supports(PlatformFeatureSupportFlag.listSongRelations);
  }
}
