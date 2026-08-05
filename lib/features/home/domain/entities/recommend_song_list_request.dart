class RecommendSongListRequest {
  const RecommendSongListRequest({required this.id, required this.platform});

  final String id;
  final String platform;

  String get cacheKey => '$platform|$id';
}
