import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/update/domain/entities/github_download_proxy_config.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release_asset.dart';
import 'package:he_music_flutter/features/update/domain/services/android_update_download_resolver.dart';

void main() {
  const resolver = AndroidUpdateDownloadResolver();

  test('selects APK using device ABI priority instead of asset order', () {
    final target = resolver.resolve(
      assets: <UpdateReleaseAsset>[_asset('x86_64'), _asset('arm64-v8a')],
      supportedAbis: const <String>['arm64-v8a', 'x86_64'],
      owner: 'owner',
      repo: 'repo',
      accelerationEnabled: false,
      selectedProxyId: null,
      proxyConfig: null,
    );

    expect(target?.officialUrl, contains('android-arm64-v8a.apk'));
    expect(target?.downloadUrl, target?.officialUrl);
    expect(target?.accelerated, isFalse);
  });

  test('prepends the selected HTTPS proxy when acceleration is enabled', () {
    final target = resolver.resolve(
      assets: <UpdateReleaseAsset>[_asset('arm64-v8a')],
      supportedAbis: const <String>['arm64-v8a'],
      owner: 'owner',
      repo: 'repo',
      accelerationEnabled: true,
      selectedProxyId: 'secondary',
      proxyConfig: _proxyConfig(),
    );

    expect(
      target?.downloadUrl,
      startsWith('https://secondary.example.com/https://github.com/'),
    );
    expect(target?.accelerated, isTrue);
  });

  test('falls back to recommended proxy when selected id is unavailable', () {
    final target = resolver.resolve(
      assets: <UpdateReleaseAsset>[_asset('arm64-v8a')],
      supportedAbis: const <String>['arm64-v8a'],
      owner: 'owner',
      repo: 'repo',
      accelerationEnabled: true,
      selectedProxyId: 'removed',
      proxyConfig: _proxyConfig(),
    );

    expect(
      target?.downloadUrl,
      startsWith('https://primary.example.com/https://github.com/'),
    );
  });

  test('falls back to official URL when no proxy is available', () {
    final target = resolver.resolve(
      assets: <UpdateReleaseAsset>[_asset('arm64-v8a')],
      supportedAbis: const <String>['arm64-v8a'],
      owner: 'owner',
      repo: 'repo',
      accelerationEnabled: true,
      selectedProxyId: null,
      proxyConfig: GitHubDownloadProxyConfig(
        schemaVersion: 1,
        revision: 1,
        defaultProxyId: null,
        proxies: const <GitHubDownloadProxy>[],
      ),
    );

    expect(target?.downloadUrl, target?.officialUrl);
    expect(target?.accelerated, isFalse);
  });

  test('rejects assets outside the configured GitHub repository', () {
    for (final url in <String>[
      'https://example.com/owner/repo/releases/download/v1.1.0/app.apk',
      'https://github.com/other/repo/releases/download/v1.1.0/HE-Music-v1.1.0-android-arm64-v8a.apk',
      'https://github.com/owner/repo/releases/download/v1.1.0/HE-Music-v1.1.0-android-arm64-v8a.apk?token=value',
    ]) {
      final target = resolver.resolve(
        assets: <UpdateReleaseAsset>[
          UpdateReleaseAsset(
            name: 'HE-Music-v1.1.0-android-arm64-v8a.apk',
            browserDownloadUrl: url,
          ),
        ],
        supportedAbis: const <String>['arm64-v8a'],
        owner: 'owner',
        repo: 'repo',
        accelerationEnabled: false,
        selectedProxyId: null,
        proxyConfig: null,
      );

      expect(target, isNull, reason: url);
    }
  });

  test('returns null when no APK matches the supported ABIs', () {
    final target = resolver.resolve(
      assets: <UpdateReleaseAsset>[_asset('x86_64')],
      supportedAbis: const <String>['arm64-v8a'],
      owner: 'owner',
      repo: 'repo',
      accelerationEnabled: false,
      selectedProxyId: null,
      proxyConfig: null,
    );

    expect(target, isNull);
  });
}

UpdateReleaseAsset _asset(String abi) {
  final name = 'HE-Music-v1.1.0-android-$abi.apk';
  return UpdateReleaseAsset(
    name: name,
    browserDownloadUrl:
        'https://github.com/owner/repo/releases/download/v1.1.0/$name',
  );
}

GitHubDownloadProxyConfig _proxyConfig() {
  return GitHubDownloadProxyConfig(
    schemaVersion: 1,
    revision: 1,
    defaultProxyId: 'primary',
    proxies: const <GitHubDownloadProxy>[
      GitHubDownloadProxy(
        id: 'primary',
        name: 'Primary',
        urlPrefix: 'https://primary.example.com/',
        enabled: true,
      ),
      GitHubDownloadProxy(
        id: 'secondary',
        name: 'Secondary',
        urlPrefix: 'https://secondary.example.com/',
        enabled: true,
      ),
    ],
  );
}
