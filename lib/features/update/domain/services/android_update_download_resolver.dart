import '../entities/github_download_proxy_config.dart';
import '../entities/update_release_asset.dart';

class UpdateDownloadTarget {
  const UpdateDownloadTarget({
    required this.officialUrl,
    required this.downloadUrl,
    required this.accelerated,
  });

  final String officialUrl;
  final String downloadUrl;
  final bool accelerated;
}

class AndroidUpdateDownloadResolver {
  const AndroidUpdateDownloadResolver();

  UpdateDownloadTarget? resolve({
    required List<UpdateReleaseAsset> assets,
    required List<String> supportedAbis,
    required String owner,
    required String repo,
    required bool accelerationEnabled,
    required String? selectedProxyId,
    required GitHubDownloadProxyConfig? proxyConfig,
  }) {
    final asset = _selectAsset(assets, supportedAbis);
    if (asset == null || !_isTrustedAssetUrl(asset, owner, repo)) {
      return null;
    }
    final officialUrl = asset.browserDownloadUrl;
    if (!accelerationEnabled) {
      return UpdateDownloadTarget(
        officialUrl: officialUrl,
        downloadUrl: officialUrl,
        accelerated: false,
      );
    }
    final proxy = proxyConfig?.resolveProxy(selectedProxyId);
    if (proxy == null) {
      return UpdateDownloadTarget(
        officialUrl: officialUrl,
        downloadUrl: officialUrl,
        accelerated: false,
      );
    }
    final acceleratedUrl = '${proxy.urlPrefix}$officialUrl';
    final acceleratedUri = Uri.tryParse(acceleratedUrl);
    if (acceleratedUri == null ||
        acceleratedUri.scheme != 'https' ||
        acceleratedUri.host.isEmpty ||
        acceleratedUri.userInfo.isNotEmpty) {
      return UpdateDownloadTarget(
        officialUrl: officialUrl,
        downloadUrl: officialUrl,
        accelerated: false,
      );
    }
    return UpdateDownloadTarget(
      officialUrl: officialUrl,
      downloadUrl: acceleratedUrl,
      accelerated: true,
    );
  }

  UpdateReleaseAsset? _selectAsset(
    List<UpdateReleaseAsset> assets,
    List<String> supportedAbis,
  ) {
    for (final rawAbi in supportedAbis) {
      final abi = rawAbi.trim();
      if (abi.isEmpty) {
        continue;
      }
      final suffix = '-android-$abi.apk';
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
