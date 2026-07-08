class PlayerQueueSource {
  const PlayerQueueSource({
    required this.routePath,
    required this.queryParameters,
    required this.title,
  });

  final String routePath;
  final Map<String, String> queryParameters;
  final String title;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'route_path': routePath,
      'query_parameters': queryParameters,
      'title': title,
    };
  }

  factory PlayerQueueSource.fromMap(Map<String, dynamic> raw) {
    final routePath = '${raw['route_path'] ?? ''}'.trim();
    final title = '${raw['title'] ?? ''}'.trim();
    final queryParametersRaw = raw['query_parameters'];
    final queryParameters = <String, String>{};
    if (queryParametersRaw is Map) {
      for (final entry in queryParametersRaw.entries) {
        final key = '${entry.key}'.trim();
        final value = '${entry.value}'.trim();
        if (key.isEmpty || value.isEmpty) {
          continue;
        }
        queryParameters[key] = value;
      }
    }
    return PlayerQueueSource(
      routePath: routePath,
      queryParameters: queryParameters,
      title: title,
    );
  }

  bool get isValid => routePath.trim().isNotEmpty;
}
