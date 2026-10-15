import 'song_detail_content.dart';

class SongDetailState {
  const SongDetailState({
    required this.loading,
    this.content,
    this.errorMessage,
  });

  final bool loading;
  final SongDetailContent? content;
  final String? errorMessage;

  SongDetailState copyWith({
    bool? loading,
    SongDetailContent? content,
    String? errorMessage,
    bool clearContent = false,
    bool clearError = false,
  }) {
    return SongDetailState(
      loading: loading ?? this.loading,
      content: clearContent ? null : content ?? this.content,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const initial = SongDetailState(loading: true);
}
