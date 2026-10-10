import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/update/application/update_download_target_service.dart';
import 'package:he_music_flutter/features/update/domain/entities/github_download_proxy_config.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release_asset.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_version.dart';
import 'package:he_music_flutter/features/update/domain/services/update_download_resolver.dart';

void main() {
  test('unsupported platform does not load ABI or proxy state', () async {
    final service = UpdateDownloadTargetService(
      platform: () => UpdateDownloadPlatform.unsupported,
      loadSupportedAbis: () async => throw StateError('should not load ABIs'),
      loadProxyConfig: () async => throw StateError('should not load proxies'),
      owner: 'owner',
      repo: 'repo',
    );
    expect(await service.resolve(_release(), AppConfigState.initial), isNull);
  });

  for (final platform in [
    UpdateDownloadPlatform.android,
    UpdateDownloadPlatform.ios,
  ]) {
    test(
      '$platform offers both downloads with the default app config',
      () async {
        var abiLoads = 0;
        var proxyLoads = 0;
        final service = UpdateDownloadTargetService(
          platform: () => platform,
          loadSupportedAbis: () async {
            abiLoads += 1;
            return ['arm64-v8a'];
          },
          loadProxyConfig: () async {
            proxyLoads += 1;
            return _proxySnapshot();
          },
          owner: 'owner',
          repo: 'repo',
        );
        final target = await service.resolve(
          _release(),
          AppConfigState.initial,
        );
        expect(target, isNotNull);
        expect(
          target?.officialUrl,
          endsWith(
            platform == UpdateDownloadPlatform.ios
                ? '-ios.ipa'
                : '-android-arm64-v8a.apk',
          ),
        );
        expect(
          target?.acceleratedUrl,
          'https://proxy.example.com/${target?.officialUrl}',
        );
        expect(abiLoads, platform == UpdateDownloadPlatform.android ? 1 : 0);
        expect(proxyLoads, 1);
      },
    );

    test(
      '$platform proxy load failure preserves only the official URL',
      () async {
        final service = UpdateDownloadTargetService(
          platform: () => platform,
          loadSupportedAbis: () async => ['arm64-v8a'],
          loadProxyConfig: () async => throw StateError('cache failed'),
          owner: 'owner',
          repo: 'repo',
        );
        final target = await service.resolve(
          _release(),
          AppConfigState.initial,
        );
        expect(target, isNotNull);
        expect(target?.officialUrl, startsWith('https://github.com/'));
        expect(target?.acceleratedUrl, isNull);
      },
    );

    test('$platform missing package does not load proxy state', () async {
      final service = UpdateDownloadTargetService(
        platform: () => platform,
        loadSupportedAbis: () async => ['arm64-v8a'],
        loadProxyConfig: () async =>
            throw StateError('should not load proxies'),
        owner: 'owner',
        repo: 'repo',
      );
      expect(
        await service.resolve(_release(assets: []), AppConfigState.initial),
        isNull,
      );
    });
  }

  test('Android ABI lookup failure leaves the release page fallback', () async {
    final service = UpdateDownloadTargetService(
      platform: () => UpdateDownloadPlatform.android,
      loadSupportedAbis: () async => throw StateError('device info failed'),
      loadProxyConfig: () async => throw StateError('should not load proxies'),
      owner: 'owner',
      repo: 'repo',
    );
    expect(await service.resolve(_release(), AppConfigState.initial), isNull);
  });
}

UpdateRelease _release({List<UpdateReleaseAsset>? assets}) {
  return UpdateRelease(
    version: UpdateVersion.parse('1.1.0'),
    versionTag: 'v1.1.0',
    title: 'v1.1.0',
    releaseNotes: 'notes',
    htmlUrl: 'https://github.com/owner/repo/releases/tag/v1.1.0',
    publishedAt: DateTime.parse('2026-07-27T12:00:00Z'),
    assets:
        assets ??
        [
          for (final suffix in ['android-arm64-v8a.apk', 'ios.ipa'])
            UpdateReleaseAsset(
              name: 'HE-Music-v1.1.0-$suffix',
              browserDownloadUrl:
                  'https://github.com/owner/repo/releases/download/v1.1.0/HE-Music-v1.1.0-$suffix',
            ),
        ],
  );
}

GitHubDownloadProxyConfigSnapshot _proxySnapshot() {
  return GitHubDownloadProxyConfigSnapshot(
    config: GitHubDownloadProxyConfig(
      schemaVersion: 1,
      revision: 1,
      defaultProxyId: 'primary',
      proxies: const [
        GitHubDownloadProxy(
          id: 'primary',
          name: 'Primary',
          urlPrefix: 'https://proxy.example.com/',
          enabled: true,
        ),
      ],
    ),
  );
}
