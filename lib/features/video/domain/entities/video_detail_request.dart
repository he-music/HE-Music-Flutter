class VideoDetailRequest {
  const VideoDetailRequest({
    required this.id,
    required this.platform,
    required this.title,
  });

  final String id;
  final String platform;
  final String title;

  String get cacheKey => '$platform|$id';
}
