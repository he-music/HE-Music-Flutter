import 'artist_detail_content.dart';

class ArtistDetailState {
  const ArtistDetailState({
    required this.loading,
    this.content,
    this.errorMessage,
  });

  final bool loading;
  final ArtistDetailContent? content;
  final String? errorMessage;

  ArtistDetailState copyWith({
    bool? loading,
    ArtistDetailContent? content,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ArtistDetailState(
      loading: loading ?? this.loading,
      content: content ?? this.content,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const initial = ArtistDetailState(loading: false);
}
