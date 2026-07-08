import '../../features/online/domain/entities/online_platform.dart';

String resolvePlatformLabel(
  String platformId, {
  List<OnlinePlatform> platforms = const <OnlinePlatform>[],
}) {
  final normalized = platformId.trim();
  if (normalized.isEmpty) {
    return '';
  }
  if (normalized.toLowerCase() == 'local') {
    return 'LOCAL';
  }
  for (final platform in platforms) {
    if (platform.id == normalized) {
      final name = platform.name.trim();
      if (name.isNotEmpty) {
        return name;
      }
      break;
    }
  }
  return normalized.toUpperCase();
}
