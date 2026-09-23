import '../../../app/config/app_environment.dart';
import '../domain/entities/update_check_result.dart';
import '../domain/entities/update_release.dart';
import '../domain/entities/update_release_asset.dart';
import '../domain/entities/update_version.dart';
import '../domain/entities/update_release_page.dart';
import '../domain/repositories/update_repository.dart';
import 'github_release_api_client.dart';

class GitHubReleaseRepositoryImpl implements UpdateRepository {
  GitHubReleaseRepositoryImpl(this._apiClient, {String? owner, String? repo})
    : _owner = owner ?? AppEnvironment.githubOwner,
      _repo = repo ?? AppEnvironment.githubRepo;

  final GitHubReleaseApiClient _apiClient;
  final String _owner;
  final String _repo;

  @override
  Future<UpdateCheckResult> checkForUpdates({
    required UpdateVersion currentVersion,
  }) async {
    if (_owner.trim().isEmpty || _repo.trim().isEmpty) {
      throw StateError('未配置 GitHub Release 仓库。');
    }
    final data = await _apiClient.fetchLatestRelease(
      owner: _owner,
      repo: _repo,
    );
    final isDraft = data['draft'] == true;
    final isPrerelease = data['prerelease'] == true;
    if (isDraft || isPrerelease) {
      return const UpdateCheckResult.latest();
    }
    final tag = '${data['tag_name'] ?? ''}'.trim();
    final htmlUrl = '${data['html_url'] ?? ''}'.trim();
    if (tag.isEmpty || htmlUrl.isEmpty) {
      throw const FormatException('GitHub Release 数据不完整。');
    }
    final latestVersion = UpdateVersion.parse(tag);
    if (latestVersion.compareTo(currentVersion) <= 0) {
      return const UpdateCheckResult.latest();
    }
    return UpdateCheckResult.available(_decodeRelease(data));
  }

  @override
  Future<UpdateReleasePage> fetchReleaseHistory(int page) async {
    if (_owner.trim().isEmpty || _repo.trim().isEmpty) {
      throw StateError('未配置 GitHub Release 仓库。');
    }
    const pageSize = 30;
    final data = await _apiClient.fetchReleases(
      owner: _owner,
      repo: _repo,
      page: page,
      perPage: pageSize,
    );
    final releases = <UpdateRelease>[];
    for (final entry in data) {
      if (entry['draft'] == true || entry['prerelease'] == true) continue;
      try {
        releases.add(_decodeRelease(entry));
      } on FormatException {
        // 历史标签可能不是应用版本；跳过它们，但继续按原始页大小分页。
      }
    }
    releases.sort((a, b) => b.version.compareTo(a.version));
    return UpdateReleasePage(
      releases: List.unmodifiable(releases),
      hasMore: data.length == pageSize,
    );
  }

  UpdateRelease _decodeRelease(Map<String, dynamic> data) {
    final tag = '${data['tag_name'] ?? ''}'.trim();
    final htmlUrl = '${data['html_url'] ?? ''}'.trim();
    if (htmlUrl.isEmpty) throw const FormatException('缺少 Release 链接');
    return UpdateRelease(
      version: UpdateVersion.parse(tag),
      versionTag: tag,
      title: '${data['name'] ?? ''}'.trim(),
      releaseNotes: '${data['body'] ?? ''}'.trim(),
      htmlUrl: htmlUrl,
      publishedAt:
          DateTime.tryParse('${data['published_at'] ?? ''}'.trim()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      assets: _decodeAssets(data['assets']),
    );
  }

  List<UpdateReleaseAsset> _decodeAssets(Object? source) {
    if (source is! List) {
      return const <UpdateReleaseAsset>[];
    }
    final assets = <UpdateReleaseAsset>[];
    for (final rawAsset in source) {
      if (rawAsset is! Map) {
        continue;
      }
      final map = rawAsset.map<String, Object?>(
        (dynamic key, dynamic value) => MapEntry('$key', value),
      );
      final name = map['name'];
      final browserDownloadUrl = map['browser_download_url'];
      if (name is! String ||
          name.trim().isEmpty ||
          browserDownloadUrl is! String ||
          browserDownloadUrl.trim().isEmpty) {
        continue;
      }
      assets.add(
        UpdateReleaseAsset(
          name: name.trim(),
          browserDownloadUrl: browserDownloadUrl.trim(),
        ),
      );
    }
    return assets;
  }
}
