import 'recommend_song_list_info.dart';

class RecommendSongListState {
  const RecommendSongListState({
    required this.loading,
    this.info,
    this.errorMessage,
  });

  final bool loading;
  final RecommendSongListInfo? info;
  final String? errorMessage;

  RecommendSongListState copyWith({
    bool? loading,
    RecommendSongListInfo? info,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RecommendSongListState(
      loading: loading ?? this.loading,
      info: info ?? this.info,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const initial = RecommendSongListState(loading: true);
}
