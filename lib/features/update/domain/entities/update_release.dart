import 'update_version.dart';

class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.versionTag,
    required this.title,
    required this.releaseNotes,
    required this.htmlUrl,
    required this.publishedAt,
  });

  final UpdateVersion version;
  final String versionTag;
  final String title;
  final String releaseNotes;
  final String htmlUrl;
  final DateTime publishedAt;
}
