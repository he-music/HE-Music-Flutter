import '../entities/github_download_proxy_config.dart';

abstract class GitHubDownloadProxyRepository {
  Future<GitHubDownloadProxyConfigSnapshot> loadLocal();

  Future<GitHubDownloadProxyConfigSnapshot> refresh();
}
