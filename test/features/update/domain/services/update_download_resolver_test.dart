import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/update/domain/entities/github_download_proxy_config.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release_asset.dart';
import 'package:he_music_flutter/features/update/domain/services/update_download_resolver.dart';

void main() {
  const resolver = UpdateDownloadResolver();

  test('selects APK using device ABI priority instead of asset order', () {
    final target = resolver.resolve(
      platform: UpdateDownloadPlatform.android,
      assets: [_asset('android-x86_64.apk'), _asset('android-arm64-v8a.apk')],
      supportedAbis: ['arm64-v8a', 'x86_64'],
      owner: 'owner',
      repo: 'repo',
      selectedProxyId: null,
      proxyConfig: null,
    );
    expect(target?.officialUrl, contains('android-arm64-v8a.apk'));
    expect(target?.acceleratedUrl, isNull);
  });

  for (final platform in [
    UpdateDownloadPlatform.android,
    UpdateDownloadPlatform.ios,
  ]) {
    final suffix = platform == UpdateDownloadPlatform.ios
        ? 'ios.ipa'
        : 'android-arm64-v8a.apk';
    test('$platform keeps official URL and uses the selected proxy', () {
      final target = resolver.resolve(
        platform: platform,
        assets: [_asset(suffix)],
        supportedAbis: ['arm64-v8a'],
        owner: 'owner',
        repo: 'repo',
        selectedProxyId: 'secondary',
        proxyConfig: _proxyConfig(),
      );
      expect(target?.officialUrl, _asset(suffix).browserDownloadUrl);
      expect(
        target?.acceleratedUrl,
        'https://secondary.example.com/${target?.officialUrl}',
      );
    });

    test(
      '$platform uses the default proxy when selected id is unavailable',
      () {
        final target = resolver.resolve(
          platform: platform,
          assets: [_asset(suffix)],
          supportedAbis: ['arm64-v8a'],
          owner: 'owner',
          repo: 'repo',
          selectedProxyId: 'removed',
          proxyConfig: _proxyConfig(),
        );
        expect(
          target?.acceleratedUrl,
          'https://primary.example.com/${target?.officialUrl}',
        );
      },
    );

    test(
      '$platform offers only official download when no proxy is available',
      () {
        final target = resolver.resolve(
          platform: platform,
          assets: [_asset(suffix)],
          supportedAbis: ['arm64-v8a'],
          owner: 'owner',
          repo: 'repo',
          selectedProxyId: null,
          proxyConfig: GitHubDownloadProxyConfig(
            schemaVersion: 1,
            revision: 1,
            defaultProxyId: null,
            proxies: [],
          ),
        );
        expect(target?.officialUrl, _asset(suffix).browserDownloadUrl);
        expect(target?.acceleratedUrl, isNull);
      },
    );

    test('$platform rejects assets outside the configured repository', () {
      for (final url in [
        'https://example.com/owner/repo/releases/download/v1.1.0/HE-Music-v1.1.0-$suffix',
        'https://github.com/other/repo/releases/download/v1.1.0/HE-Music-v1.1.0-$suffix',
        '${_asset(suffix).browserDownloadUrl}?token=value',
      ]) {
        final target = resolver.resolve(
          platform: platform,
          assets: [
            UpdateReleaseAsset(
              name: _asset(suffix).name,
              browserDownloadUrl: url,
            ),
          ],
          supportedAbis: ['arm64-v8a'],
          owner: 'owner',
          repo: 'repo',
          selectedProxyId: null,
          proxyConfig: _proxyConfig(),
        );
        expect(target, isNull, reason: url);
      }
    });
  }

  test('iOS selects IPA from mixed assets without needing Android ABIs', () {
    final target = resolver.resolve(
      platform: UpdateDownloadPlatform.ios,
      assets: [_asset('android-arm64-v8a.apk'), _asset('ios.ipa')],
      supportedAbis: [],
      owner: 'owner',
      repo: 'repo',
      selectedProxyId: null,
      proxyConfig: _proxyConfig(),
    );
    expect(target?.officialUrl, endsWith('-ios.ipa'));
    expect(target?.acceleratedUrl, endsWith('-ios.ipa'));
  });

  test('returns null when no package matches platform or supported ABIs', () {
    for (final platform in UpdateDownloadPlatform.values) {
      final target = resolver.resolve(
        platform: platform,
        assets: [_asset('android-x86_64.apk')],
        supportedAbis: ['arm64-v8a'],
        owner: 'owner',
        repo: 'repo',
        selectedProxyId: null,
        proxyConfig: null,
      );
      expect(target, isNull, reason: platform.name);
    }
  });
}

UpdateReleaseAsset _asset(String suffix) {
  final name = 'HE-Music-v1.1.0-$suffix';
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
    proxies: const [
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
