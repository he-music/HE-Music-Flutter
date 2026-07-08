import 'album_detail_content.dart';

class AlbumDetailState {
  const AlbumDetailState({
    required this.loading,
    this.content,
    this.errorMessage,
  });

  final bool loading;
  final AlbumDetailContent? content;
  final String? errorMessage;

  AlbumDetailState copyWith({
    bool? loading,
    AlbumDetailContent? content,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AlbumDetailState(
      loading: loading ?? this.loading,
      content: content ?? this.content,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const initial = AlbumDetailState(loading: false);
}
