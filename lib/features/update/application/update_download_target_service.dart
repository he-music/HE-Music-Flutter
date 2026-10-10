import '../../../app/config/app_config_state.dart';
import '../domain/entities/github_download_proxy_config.dart';
import '../domain/entities/update_release.dart';
import '../domain/services/update_download_resolver.dart';

class UpdateDownloadTargetService {
  UpdateDownloadTargetService({
    required UpdateDownloadPlatform Function() platform,
    required Future<List<String>> Function() loadSupportedAbis,
    required Future<GitHubDownloadProxyConfigSnapshot> Function()
    loadProxyConfig,
    required String owner,
    required String repo,
    UpdateDownloadResolver resolver = const UpdateDownloadResolver(),
  }) : _platform = platform,
       _loadSupportedAbis = loadSupportedAbis,
       _loadProxyConfig = loadProxyConfig,
       _owner = owner,
       _repo = repo,
       _resolver = resolver;

  final UpdateDownloadPlatform Function() _platform;
  final Future<List<String>> Function() _loadSupportedAbis;
  final Future<GitHubDownloadProxyConfigSnapshot> Function() _loadProxyConfig;
  final String _owner;
  final String _repo;
  final UpdateDownloadResolver _resolver;

  Future<UpdateDownloadTarget?> resolve(
    UpdateRelease release,
    AppConfigState appConfig,
  ) async {
    final platform = _platform();
    if (platform == UpdateDownloadPlatform.unsupported) {
      return null;
    }
    var supportedAbis = const <String>[];
    if (platform == UpdateDownloadPlatform.android) {
      try {
        supportedAbis = await _loadSupportedAbis();
      } catch (_) {
        return null;
      }
    }
    final officialTarget = _resolver.resolve(
      platform: platform,
      assets: release.assets,
      supportedAbis: supportedAbis,
      owner: _owner,
      repo: _repo,
      selectedProxyId: appConfig.githubDownloadProxyId,
      proxyConfig: null,
    );
    if (officialTarget == null) {
      return null;
    }
    final GitHubDownloadProxyConfig proxyConfig;
    try {
      proxyConfig = (await _loadProxyConfig()).config;
    } catch (_) {
      // 配置加载失败时仍提供普通下载，不将原始地址标记为加速地址。
      return officialTarget;
    }
    return _resolver.resolve(
      platform: platform,
      assets: release.assets,
      supportedAbis: supportedAbis,
      owner: _owner,
      repo: _repo,
      selectedProxyId: appConfig.githubDownloadProxyId,
      proxyConfig: proxyConfig,
    );
  }
}
