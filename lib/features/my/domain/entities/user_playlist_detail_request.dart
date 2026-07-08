class UserPlaylistDetailRequest {
  const UserPlaylistDetailRequest({required this.id, required this.title});

  final String id;
  final String title;

  String get cacheKey => id;
}
