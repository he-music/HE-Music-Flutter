import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/video_feed_state.dart';
import '../providers/video_feed_providers.dart';

class VideoFeedController extends Notifier<VideoFeedState> {
  String _initialId = '';
  String _initialPlatform = '';

  @override
  VideoFeedState build() {
    return VideoFeedState.initial;
  }

  /// 设置初始视频（来自 Detail API），作为列表第一项。
  void setInitialVideo(MvInfo video) {
    _initialId = video.id;
    _initialPlatform = video.platform;
    state = VideoFeedState.initial.copyWith(
      videos: <MvInfo>[video],
      currentIndex: 0,
    );
  }

  /// 当前平台是否支持 feed 流加载更多。
  bool get supportsFeed => _platformSupportsFeed(_initialPlatform);

  /// 加载 feed 第一页，追加到初始视频之后。
  Future<void> loadFeed() async {
    if (_initialId.isEmpty || state.loadingMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final result = await _apiClient.fetchMvFeed(
        id: _initialId,
        platform: _initialPlatform,
        pageIndex: 1,
      );
      state = state.copyWith(
        loadingMore: false,
        videos: <MvInfo>[...state.videos, ...result.list],
        hasMore: result.hasMore,
        pageIndex: 2,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  /// 翻到指定索引，接近末尾时自动加载更多。
  Future<void> onPageChanged(int index) async {
    state = state.copyWith(currentIndex: index);
    if (state.hasMore &&
        !state.loadingMore &&
        index >= state.videos.length - 3) {
      await loadMore();
    }
  }

  /// 加载下一页 feed。
  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final result = await _apiClient.fetchMvFeed(
        id: _initialId,
        platform: _initialPlatform,
        pageIndex: state.pageIndex,
      );
      state = state.copyWith(
        loadingMore: false,
        videos: <MvInfo>[...state.videos, ...result.list],
        hasMore: result.hasMore,
        pageIndex: state.pageIndex + 1,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  bool _platformSupportsFeed(String platformId) {
    try {
      final platforms = ref.read(onlinePlatformsProvider).value;
      if (platforms == null) return false;
      final platform = platforms.where((p) => p.id == platformId).firstOrNull;
      return platform?.supports(PlatformFeatureSupportFlag.listMVFeeds) ??
          false;
    } catch (_) {
      return false;
    }
  }

  dynamic get _apiClient => ref.read(videoFeedApiClientProvider);
}
