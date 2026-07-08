import 'playlist_detail_content.dart';

class PlaylistDetailState {
  const PlaylistDetailState({
    required this.loading,
    this.content,
    this.errorMessage,
  });

  final bool loading;
  final PlaylistDetailContent? content;
  final String? errorMessage;

  PlaylistDetailState copyWith({
    bool? loading,
    PlaylistDetailContent? content,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlaylistDetailState(
      loading: loading ?? this.loading,
      content: content ?? this.content,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const initial = PlaylistDetailState(loading: false);
}
