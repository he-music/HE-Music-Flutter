import '../../../app/config/app_environment.dart';
import '../domain/entities/update_check_result.dart';
import '../domain/entities/update_release.dart';
import '../domain/entities/update_version.dart';
import '../domain/repositories/update_repository.dart';
import 'github_release_api_client.dart';

class GitHubReleaseRepositoryImpl implements UpdateRepository {
  GitHubReleaseRepositoryImpl(this._apiClient);

  final GitHubReleaseApiClient _apiClient;

  @override
  Future<UpdateCheckResult> checkForUpdates({
    required UpdateVersion currentVersion,
  }) async {
    if (!AppEnvironment.hasGitHubReleaseConfig) {
      throw StateError('未配置 GitHub Release 仓库。');
    }
    final data = await _apiClient.fetchLatestRelease(
      owner: AppEnvironment.githubOwner,
      repo: AppEnvironment.githubRepo,
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
    final release = UpdateRelease(
      version: latestVersion,
      versionTag: tag,
      title: '${data['name'] ?? ''}'.trim(),
      releaseNotes: '${data['body'] ?? ''}'.trim(),
      htmlUrl: htmlUrl,
      publishedAt:
          DateTime.tryParse('${data['published_at'] ?? ''}'.trim()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
    return UpdateCheckResult.available(release);
  }
}
