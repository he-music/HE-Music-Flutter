import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/update/application/github_download_proxy_auto_refresh_service.dart';
import 'package:he_music_flutter/features/update/domain/entities/github_download_proxy_config.dart';

void main() {
  test('non-Android platform does not load or refresh proxy config', () async {
    final harness = _AutoRefreshHarness(isAndroid: false);

    final refreshed = await harness.service.refreshIfNeeded(
      _enabledAppConfig(),
    );

    expect(refreshed, isFalse);
    expect(harness.loadCalls, 0);
    expect(harness.refreshCalls, 0);
  });

  test('disabled acceleration does not load or refresh proxy config', () async {
    final harness = _AutoRefreshHarness();

    final refreshed = await harness.service.refreshIfNeeded(
      AppConfigState.initial,
    );

    expect(refreshed, isFalse);
    expect(harness.loadCalls, 0);
    expect(harness.refreshCalls, 0);
  });

  test(
    'disabled automatic updates do not load or refresh proxy config',
    () async {
      final harness = _AutoRefreshHarness();

      final refreshed = await harness.service.refreshIfNeeded(
        _enabledAppConfig().copyWith(
          githubDownloadProxyAutoUpdateEnabled: false,
        ),
      );

      expect(refreshed, isFalse);
      expect(harness.loadCalls, 0);
      expect(harness.refreshCalls, 0);
    },
  );

  test('config refreshed less than 24 hours ago is not refreshed', () async {
    final harness = _AutoRefreshHarness(
      refreshedAt: DateTime.parse('2026-07-27T12:00:01Z'),
    );

    final refreshed = await harness.service.refreshIfNeeded(
      _enabledAppConfig(),
    );

    expect(refreshed, isFalse);
    expect(harness.loadCalls, 1);
    expect(harness.refreshCalls, 0);
  });

  test('config refreshed exactly 24 hours ago is refreshed', () async {
    final harness = _AutoRefreshHarness(
      refreshedAt: DateTime.parse('2026-07-27T12:00:00Z'),
    );

    final refreshed = await harness.service.refreshIfNeeded(
      _enabledAppConfig(),
    );

    expect(refreshed, isTrue);
    expect(harness.loadCalls, 1);
    expect(harness.refreshCalls, 1);
  });

  test('config that has never been remotely refreshed is refreshed', () async {
    final harness = _AutoRefreshHarness();

    final refreshed = await harness.service.refreshIfNeeded(
      _enabledAppConfig(),
    );

    expect(refreshed, isTrue);
    expect(harness.loadCalls, 1);
    expect(harness.refreshCalls, 1);
  });
}

AppConfigState _enabledAppConfig() {
  return AppConfigState.initial.copyWith(
    githubDownloadAccelerationEnabled: true,
    githubDownloadProxyAutoUpdateEnabled: true,
  );
}

class _AutoRefreshHarness {
  _AutoRefreshHarness({this.isAndroid = true, this.refreshedAt}) {
    service = GitHubDownloadProxyAutoRefreshService(
      isAndroid: () => isAndroid,
      loadLocal: () async {
        loadCalls += 1;
        return _snapshot(refreshedAt: refreshedAt);
      },
      refresh: () async {
        refreshCalls += 1;
        return _snapshot(refreshedAt: _now);
      },
      now: () => _now,
    );
  }

  static final _now = DateTime.parse('2026-07-28T12:00:00Z');

  final bool isAndroid;
  final DateTime? refreshedAt;
  late final GitHubDownloadProxyAutoRefreshService service;
  int loadCalls = 0;
  int refreshCalls = 0;
}

GitHubDownloadProxyConfigSnapshot _snapshot({DateTime? refreshedAt}) {
  return GitHubDownloadProxyConfigSnapshot(
    config: GitHubDownloadProxyConfig(
      schemaVersion: 1,
      revision: 1,
      defaultProxyId: null,
      proxies: const <GitHubDownloadProxy>[],
    ),
    refreshedAt: refreshedAt,
  );
}
