class RankingDetailRequest {
  const RankingDetailRequest({
    required this.id,
    required this.platform,
    this.title,
  });

  final String id;
  final String platform;
  final String? title;

  String get cacheKey => '$platform|$id';
}
