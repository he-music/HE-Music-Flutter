class LyricCandidate {
  const LyricCandidate({
    required this.platform,
    required this.id,
    required this.name,
    required this.artistNames,
    required this.duration,
  });
  final String platform;
  final String id;
  final String name;
  final List<String> artistNames;
  final int duration;

  factory LyricCandidate.fromJson(Map<String, dynamic> json) {
    final platform = json['platform'] as String? ?? '';
    final id = json['id'] as String? ?? '';
    if (platform.isEmpty || id.isEmpty) throw const FormatException('歌词候选身份缺失');
    return LyricCandidate(
      platform: platform,
      id: id,
      name: json['name'] as String? ?? '',
      artistNames: List<String>.from(
        json['artist_names'] ?? json['artistNames'] ?? const [],
      ),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
    );
  }
}
