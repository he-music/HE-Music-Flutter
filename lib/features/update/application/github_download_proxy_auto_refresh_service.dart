import '../../../app/config/app_config_state.dart';
import '../domain/entities/github_download_proxy_config.dart';

class GitHubDownloadProxyAutoRefreshService {
  GitHubDownloadProxyAutoRefreshService({
    required Future<GitHubDownloadProxyConfigSnapshot> Function() loadLocal,
    required Future<GitHubDownloadProxyConfigSnapshot> Function() refresh,
    DateTime Function()? now,
  }) : _loadLocal = loadLocal,
       _refresh = refresh,
       _now = now ?? DateTime.now;

  static const refreshInterval = Duration(hours: 24);

  final Future<GitHubDownloadProxyConfigSnapshot> Function() _loadLocal;
  final Future<GitHubDownloadProxyConfigSnapshot> Function() _refresh;
  final DateTime Function() _now;

  Future<bool> refreshIfNeeded(AppConfigState appConfig) async {
    if (!appConfig.githubDownloadProxyAutoUpdateEnabled) {
      return false;
    }
    final snapshot = await _loadLocal();
    final refreshedAt = snapshot.refreshedAt;
    if (refreshedAt != null &&
        _now().toUtc().difference(refreshedAt.toUtc()) < refreshInterval) {
      return false;
    }
    await _refresh();
    return true;
  }
}
