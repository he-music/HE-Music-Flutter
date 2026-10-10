import '../entities/github_download_proxy_config.dart';
import '../entities/update_release_asset.dart';

enum UpdateDownloadPlatform { android, ios, unsupported }

class UpdateDownloadTarget {
  const UpdateDownloadTarget({required this.officialUrl, this.acceleratedUrl});

  final String officialUrl;
  final String? acceleratedUrl;
}

class UpdateDownloadResolver {
  const UpdateDownloadResolver();

  UpdateDownloadTarget? resolve({
    required UpdateDownloadPlatform platform,
    required List<UpdateReleaseAsset> assets,
    required List<String> supportedAbis,
    required String owner,
    required String repo,
    required String? selectedProxyId,
    required GitHubDownloadProxyConfig? proxyConfig,
  }) {
    final asset = _selectAsset(platform, assets, supportedAbis);
    if (asset == null || !_isTrustedAssetUrl(asset, owner, repo)) {
      return null;
    }
    final officialUrl = asset.browserDownloadUrl;
    final proxy = proxyConfig?.resolveProxy(selectedProxyId);
    if (proxy == null) {
      return UpdateDownloadTarget(officialUrl: officialUrl);
    }
    final acceleratedUrl = '${proxy.urlPrefix}$officialUrl';
    final acceleratedUri = Uri.tryParse(acceleratedUrl);
    if (acceleratedUri == null ||
        acceleratedUri.scheme != 'https' ||
        acceleratedUri.host.isEmpty ||
        acceleratedUri.userInfo.isNotEmpty) {
      return UpdateDownloadTarget(officialUrl: officialUrl);
    }
    return UpdateDownloadTarget(
      officialUrl: officialUrl,
      acceleratedUrl: acceleratedUrl,
    );
  }

  UpdateReleaseAsset? _selectAsset(
    UpdateDownloadPlatform platform,
    List<UpdateReleaseAsset> assets,
    List<String> supportedAbis,
  ) {
    final suffixes = switch (platform) {
      UpdateDownloadPlatform.android =>
        supportedAbis
            .map((abi) => abi.trim())
            .where((abi) => abi.isNotEmpty)
            .map((abi) => '-android-$abi.apk'),
      UpdateDownloadPlatform.ios => const ['-ios.ipa'],
      UpdateDownloadPlatform.unsupported => const <String>[],
    };
    for (final suffix in suffixes) {
      for (final asset in assets) {
        if (asset.name.endsWith(suffix)) {
          return asset;
        }
      }
    }
    return null;
  }

  bool _isTrustedAssetUrl(UpdateReleaseAsset asset, String owner, String repo) {
    final uri = Uri.tryParse(asset.browserDownloadUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }
    final segments = uri.pathSegments;
    if (segments.length != 6 ||
        segments[0].toLowerCase() != owner.trim().toLowerCase() ||
        segments[1].toLowerCase() != repo.trim().toLowerCase() ||
        segments[2] != 'releases' ||
        segments[3] != 'download' ||
        segments[4].trim().isEmpty ||
        segments[5] != asset.name) {
      return false;
    }
    return true;
  }
}
