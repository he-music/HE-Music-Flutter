class LyricRequest {
  const LyricRequest({required this.trackId, this.platform, this.localPath});

  final String trackId;
  final String? platform;
  final String? localPath;

  String get cacheKey => '${platform ?? ''}::$trackId::${localPath ?? ''}';

  @override
  bool operator ==(Object other) {
    return other is LyricRequest &&
        other.trackId == trackId &&
        other.platform == platform &&
        other.localPath == localPath;
  }

  @override
  int get hashCode => Object.hash(trackId, platform, localPath);
}
