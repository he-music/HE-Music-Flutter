import '../domain/entities/github_download_proxy_config.dart';
import '../domain/repositories/github_download_proxy_repository.dart';
import 'github_download_proxy_config_data_source.dart';
import 'github_release_api_client.dart';

class GitHubDownloadProxyRepositoryImpl
    implements GitHubDownloadProxyRepository {
  GitHubDownloadProxyRepositoryImpl({
    required GitHubReleaseApiClient apiClient,
    required GitHubDownloadProxyConfigDataSource dataSource,
    required String owner,
    required String repo,
    DateTime Function()? now,
  }) : _apiClient = apiClient,
       _dataSource = dataSource,
       _owner = owner,
       _repo = repo,
       _now = now ?? DateTime.now;

  final GitHubReleaseApiClient _apiClient;
  final GitHubDownloadProxyConfigDataSource _dataSource;
  final String _owner;
  final String _repo;
  final DateTime Function() _now;

  @override
  Future<GitHubDownloadProxyConfigSnapshot> loadLocal() {
    return _dataSource.loadLocal();
  }

  @override
  Future<GitHubDownloadProxyConfigSnapshot> refresh() async {
    final rawConfig = await _apiClient.fetchDownloadProxyConfig(
      owner: _owner,
      repo: _repo,
    );
    final remoteConfig = GitHubDownloadProxyConfig.fromJsonString(rawConfig);
    final currentSnapshot = await _dataSource.loadLocal();
    if (remoteConfig.revision < currentSnapshot.config.revision) {
      return currentSnapshot;
    }
    final snapshot = GitHubDownloadProxyConfigSnapshot(
      config: remoteConfig,
      refreshedAt: _now().toUtc(),
    );
    await _dataSource.save(snapshot);
    return snapshot;
  }
}
