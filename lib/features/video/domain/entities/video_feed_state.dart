import '../../../../shared/models/he_music_models.dart';

class VideoFeedState {
  const VideoFeedState({
    required this.videos,
    required this.currentIndex,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.pageIndex,
    this.error,
  });

  final List<MvInfo> videos;
  final int currentIndex;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final int pageIndex;
  final String? error;

  MvInfo? get currentVideo =>
      videos.isEmpty ? null : videos[currentIndex.clamp(0, videos.length - 1)];

  VideoFeedState copyWith({
    List<MvInfo>? videos,
    int? currentIndex,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    int? pageIndex,
    String? error,
    bool clearError = false,
  }) {
    return VideoFeedState(
      videos: videos ?? this.videos,
      currentIndex: currentIndex ?? this.currentIndex,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      pageIndex: pageIndex ?? this.pageIndex,
      error: clearError ? null : error ?? this.error,
    );
  }

  static const initial = VideoFeedState(
    videos: <MvInfo>[],
    currentIndex: 0,
    loading: false,
    loadingMore: false,
    hasMore: false,
    pageIndex: 1,
  );
}
