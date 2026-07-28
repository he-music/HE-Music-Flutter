import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/github_download_proxy_config.dart';

const _cacheKey = 'update.github_download_proxy_config.v1';
const _bundledConfigPath = 'gh-proxy.json';

class GitHubDownloadProxyConfigDataSource {
  GitHubDownloadProxyConfigDataSource({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;

  Future<GitHubDownloadProxyConfigSnapshot> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey)?.trim() ?? '';
    GitHubDownloadProxyConfigSnapshot? cachedSnapshot;
    if (cached.isNotEmpty) {
      try {
        cachedSnapshot = GitHubDownloadProxyConfigSnapshot.fromCacheJsonString(
          cached,
        );
      } on FormatException {
        // 损坏缓存不参与运行时状态，也不覆盖内置回退配置。
      }
    }
    try {
      final bundled = await _assetBundle.loadString(_bundledConfigPath);
      final bundledSnapshot = GitHubDownloadProxyConfigSnapshot(
        config: GitHubDownloadProxyConfig.fromJsonString(bundled),
      );
      if (cachedSnapshot != null &&
          cachedSnapshot.config.revision >= bundledSnapshot.config.revision) {
        return cachedSnapshot;
      }
      return bundledSnapshot;
    } catch (_) {
      if (cachedSnapshot != null) {
        return cachedSnapshot;
      }
      rethrow;
    }
  }

  Future<void> save(GitHubDownloadProxyConfigSnapshot snapshot) async {
    final payload = snapshot.toCacheJsonString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, payload);
  }
}
