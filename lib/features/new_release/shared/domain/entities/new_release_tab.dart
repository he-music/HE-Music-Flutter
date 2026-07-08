class NewReleaseTab {
  const NewReleaseTab({
    required this.id,
    required this.name,
    required this.platform,
  });

  final String id;
  final String name;
  final String platform;

  factory NewReleaseTab.fromMap(
    Map<String, dynamic> raw, {
    String fallbackPlatform = '',
  }) {
    return NewReleaseTab(
      id: '${raw['id'] ?? ''}'.trim(),
      name: '${raw['name'] ?? ''}'.trim(),
      platform: '${raw['platform'] ?? fallbackPlatform}'.trim(),
    );
  }
}
