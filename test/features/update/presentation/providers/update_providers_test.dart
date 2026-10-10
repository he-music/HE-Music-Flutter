import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_environment.dart';
import 'package:he_music_flutter/features/update/domain/entities/github_download_proxy_config.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release_asset.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_version.dart';
import 'package:he_music_flutter/features/update/presentation/controllers/github_download_proxy_controller.dart';
import 'package:he_music_flutter/features/update/presentation/providers/update_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'iOS providers resolve both IPA downloads and refresh the service list',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await AppEnvironment.initialize();
      final container = ProviderContainer(
        overrides: [
          androidSupportedAbisProvider.overrideWith((ref) {
            fail('iOS must not request Android device information');
          }),
          gitHubDownloadProxyControllerProvider.overrideWith(
            _ProxyController.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      final releaseUrl =
          'https://github.com/${AppEnvironment.githubOwner}/${AppEnvironment.githubRepo}/releases';
      const ipaName = 'HE-Music-v1.1.0-ios.ipa';
      final officialUrl = '$releaseUrl/download/v1.1.0/$ipaName';
      final target = await container
          .read(updateDownloadTargetServiceProvider)
          .resolve(
            UpdateRelease(
              version: UpdateVersion.parse('1.1.0'),
              versionTag: 'v1.1.0',
              title: 'v1.1.0',
              releaseNotes: 'notes',
              htmlUrl: '$releaseUrl/tag/v1.1.0',
              publishedAt: DateTime(2026),
              assets: [
                UpdateReleaseAsset(
                  name: ipaName,
                  browserDownloadUrl: officialUrl,
                ),
              ],
            ),
            AppConfigState.initial,
          );
      expect(target?.officialUrl, officialUrl);
      expect(target?.acceleratedUrl, 'https://proxy.example.com/$officialUrl');

      final refreshed = await container
          .read(gitHubDownloadProxyAutoRefreshServiceProvider)
          .refreshIfNeeded(AppConfigState.initial);
      expect(refreshed, isTrue);
      final controller =
          container.read(gitHubDownloadProxyControllerProvider.notifier)
              as _ProxyController;
      expect(controller.refreshCalls, 1);
    },
  );
}

class _ProxyController extends GitHubDownloadProxyController {
  int refreshCalls = 0;

  @override
  Future<GitHubDownloadProxyConfigSnapshot> build() async => _snapshot();

  @override
  Future<GitHubDownloadProxyConfigSnapshot> refresh() async {
    refreshCalls += 1;
    return _snapshot();
  }
}

GitHubDownloadProxyConfigSnapshot _snapshot() {
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
