import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/update/application/update_download_target_service.dart';
import 'package:he_music_flutter/features/update/domain/entities/github_download_proxy_config.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release_asset.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_version.dart';

void main() {
  test('non-Android resolution does not load ABI or proxy state', () async {
    var abiLoads = 0;
    var proxyLoads = 0;
    final service = UpdateDownloadTargetService(
      isAndroid: () => false,
      loadSupportedAbis: () async {
        abiLoads += 1;
        return const <String>['arm64-v8a'];
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
      AppConfigState.initial.copyWith(githubDownloadAccelerationEnabled: true),
    );

    expect(target, isNull);
    expect(abiLoads, 0);
    expect(proxyLoads, 0);
  });

  test(
    'disabled acceleration resolves official APK without loading proxies',
    () async {
      var proxyLoads = 0;
      final service = UpdateDownloadTargetService(
        isAndroid: () => true,
        loadSupportedAbis: () async => const <String>['arm64-v8a'],
        loadProxyConfig: () async {
          proxyLoads += 1;
          return _proxySnapshot();
        },
        owner: 'owner',
        repo: 'repo',
      );

      final target = await service.resolve(_release(), AppConfigState.initial);

      expect(target?.downloadUrl, target?.officialUrl);
      expect(proxyLoads, 0);
    },
  );

  test('proxy load failure falls back to the official APK URL', () async {
    final service = UpdateDownloadTargetService(
      isAndroid: () => true,
      loadSupportedAbis: () async => const <String>['arm64-v8a'],
      loadProxyConfig: () async => throw StateError('cache failed'),
      owner: 'owner',
      repo: 'repo',
    );

    final target = await service.resolve(
      _release(),
      AppConfigState.initial.copyWith(githubDownloadAccelerationEnabled: true),
    );

    expect(target?.downloadUrl, target?.officialUrl);
    expect(target?.accelerated, isFalse);
  });
}

UpdateRelease _release() {
  const name = 'HE-Music-v1.1.0-android-arm64-v8a.apk';
  return UpdateRelease(
    version: UpdateVersion.parse('1.1.0'),
    versionTag: 'v1.1.0',
    title: 'v1.1.0',
    releaseNotes: 'notes',
    htmlUrl: 'https://github.com/owner/repo/releases/tag/v1.1.0',
    publishedAt: DateTime.parse('2026-07-27T12:00:00Z'),
    assets: const <UpdateReleaseAsset>[
      UpdateReleaseAsset(
        name: name,
        browserDownloadUrl:
            'https://github.com/owner/repo/releases/download/v1.1.0/$name',
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
      proxies: const <GitHubDownloadProxy>[
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
