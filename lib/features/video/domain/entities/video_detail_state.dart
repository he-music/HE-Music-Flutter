import 'video_detail_content.dart';

class VideoDetailState {
  const VideoDetailState({
    required this.loading,
    this.content,
    this.errorMessage,
  });

  final bool loading;
  final VideoDetailContent? content;
  final String? errorMessage;

  VideoDetailState copyWith({
    bool? loading,
    VideoDetailContent? content,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VideoDetailState(
      loading: loading ?? this.loading,
      content: content ?? this.content,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const initial = VideoDetailState(loading: false);
}
