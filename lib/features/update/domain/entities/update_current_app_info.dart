class UpdateCurrentAppInfo {
  const UpdateCurrentAppInfo({
    required this.appName,
    required this.version,
    required this.buildNumber,
  });

  final String appName;
  final String version;
  final String buildNumber;

  String get versionLabel {
    final normalizedBuildNumber = buildNumber.trim();
    if (normalizedBuildNumber.isEmpty) {
      return version.trim();
    }
    return '${version.trim()}+$normalizedBuildNumber';
  }
}
