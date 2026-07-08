class OnlineFeatureState {
  const OnlineFeatureState({
    required this.loading,
    required this.searchResults,
    required this.comments,
    this.profile,
    this.message,
    this.error,
  });

  final bool loading;
  final List<Map<String, dynamic>> searchResults;
  final List<Map<String, dynamic>> comments;
  final Map<String, dynamic>? profile;
  final String? message;
  final String? error;

  OnlineFeatureState copyWith({
    bool? loading,
    List<Map<String, dynamic>>? searchResults,
    List<Map<String, dynamic>>? comments,
    Map<String, dynamic>? profile,
    String? message,
    String? error,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return OnlineFeatureState(
      loading: loading ?? this.loading,
      searchResults: searchResults ?? this.searchResults,
      comments: comments ?? this.comments,
      profile: profile ?? this.profile,
      message: clearMessage ? null : message ?? this.message,
      error: clearError ? null : error ?? this.error,
    );
  }

  static const initial = OnlineFeatureState(
    loading: false,
    searchResults: <Map<String, dynamic>>[],
    comments: <Map<String, dynamic>>[],
  );
}
