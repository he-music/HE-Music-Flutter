class UpdateVersion {
  const UpdateVersion({
    required this.major,
    required this.minor,
    required this.patch,
  });

  final int major;
  final int minor;
  final int patch;

  String get normalized => '$major.$minor.$patch';

  factory UpdateVersion.parse(String input) {
    final normalized = input.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(normalized);
    if (match == null) {
      throw FormatException('无效版本号: $input');
    }
    return UpdateVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
    );
  }

  int compareTo(UpdateVersion other) {
    if (major != other.major) {
      return major.compareTo(other.major);
    }
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }
    return patch.compareTo(other.patch);
  }
}
