import 'update_version.dart';
import 'update_release_asset.dart';

class UpdateRelease {
  UpdateRelease({
    required this.version,
    required this.versionTag,
    required this.title,
    required this.releaseNotes,
    required this.htmlUrl,
    required this.publishedAt,
    List<UpdateReleaseAsset> assets = const <UpdateReleaseAsset>[],
  }) : assets = List<UpdateReleaseAsset>.unmodifiable(assets);

  final UpdateVersion version;
  final String versionTag;
  final String title;
  final String releaseNotes;
  final String htmlUrl;
  final DateTime publishedAt;
  final List<UpdateReleaseAsset> assets;
}
