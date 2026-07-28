import '../../../app/config/app_config_state.dart';
import '../domain/entities/github_download_proxy_config.dart';
import '../domain/entities/update_release.dart';
import '../domain/services/android_update_download_resolver.dart';

class UpdateDownloadTargetService {
  UpdateDownloadTargetService({
    required bool Function() isAndroid,
    required Future<List<String>> Function() loadSupportedAbis,
    required Future<GitHubDownloadProxyConfigSnapshot> Function()
    loadProxyConfig,
    required String owner,
    required String repo,
    AndroidUpdateDownloadResolver resolver =
        const AndroidUpdateDownloadResolver(),
  }) : _isAndroid = isAndroid,
       _loadSupportedAbis = loadSupportedAbis,
       _loadProxyConfig = loadProxyConfig,
       _owner = owner,
       _repo = repo,
       _resolver = resolver;

  final bool Function() _isAndroid;
  final Future<List<String>> Function() _loadSupportedAbis;
  final Future<GitHubDownloadProxyConfigSnapshot> Function() _loadProxyConfig;
  final String _owner;
  final String _repo;
  final AndroidUpdateDownloadResolver _resolver;

  Future<UpdateDownloadTarget?> resolve(
    UpdateRelease release,
    AppConfigState appConfig,
  ) async {
    if (!_isAndroid()) {
      return null;
    }
    final List<String> supportedAbis;
    try {
      supportedAbis = await _loadSupportedAbis();
    } catch (_) {
      return null;
    }
    GitHubDownloadProxyConfig? proxyConfig;
    if (appConfig.githubDownloadAccelerationEnabled) {
      try {
        proxyConfig = (await _loadProxyConfig()).config;
      } catch (_) {
        proxyConfig = null;
      }
    }
    return _resolver.resolve(
      assets: release.assets,
      supportedAbis: supportedAbis,
      owner: _owner,
      repo: _repo,
      accelerationEnabled: appConfig.githubDownloadAccelerationEnabled,
      selectedProxyId: appConfig.githubDownloadProxyId,
      proxyConfig: proxyConfig,
    );
  }
}
