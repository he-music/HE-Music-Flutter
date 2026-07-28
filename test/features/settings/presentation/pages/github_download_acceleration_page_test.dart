import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/github_download_acceleration_page.dart';
import 'package:he_music_flutter/features/update/domain/entities/github_download_proxy_config.dart';
import 'package:he_music_flutter/features/update/domain/repositories/github_download_proxy_repository.dart';
import 'package:he_music_flutter/features/update/presentation/providers/update_providers.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets('initial page load uses local config without refreshing', (
    tester,
  ) async {
    final repository = _FakeRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    await _pumpPage(tester, container);

    expect(find.text('Primary Proxy'), findsOneWidget);
    expect(repository.loadCalls, 1);
    expect(repository.refreshCalls, 0);
    expect(
      container.read(appConfigProvider).githubDownloadAccelerationEnabled,
      isFalse,
    );
    expect(
      container.read(appConfigProvider).githubDownloadProxyAutoUpdateEnabled,
      isTrue,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(
              const ValueKey<String>(
                'github-download-proxy-auto-update-switch',
              ),
            ),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('automatic update switch persists its disabled state', (
    tester,
  ) async {
    final repository = _FakeRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    await _pumpPage(tester, container);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('github-download-proxy-auto-update-switch'),
      ),
    );
    await tester.pump();

    expect(
      container.read(appConfigProvider).githubDownloadProxyAutoUpdateEnabled,
      isFalse,
    );
    expect(repository.refreshCalls, 0);
  });

  testWidgets('switch enables proxy selection and persists the selected id', (
    tester,
  ) async {
    final repository = _FakeRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    await _pumpPage(tester, container);

    await tester.tap(
      find.byKey(const ValueKey<String>('github-download-acceleration-switch')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('github-download-proxy-secondary')),
    );
    await tester.pump();

    final config = container.read(appConfigProvider);
    expect(config.githubDownloadAccelerationEnabled, isTrue);
    expect(config.githubDownloadProxyId, 'secondary');
  });

  testWidgets(
    'refresh action is the only remote request and updates timestamp',
    (tester) async {
      final repository = _FakeRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      await _pumpPage(tester, container);

      await tester.tap(
        find.byKey(const ValueKey<String>('refresh-github-proxy-list')),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(repository.refreshCalls, 1);
      expect(find.textContaining('最近更新：'), findsOneWidget);
      expect(find.text('Remote Proxy'), findsOneWidget);
      expect(find.text('加速服务列表已更新'), findsOneWidget);

      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(milliseconds: 700));
    },
  );

  testWidgets('refresh preserves a valid selection changed while pending', (
    tester,
  ) async {
    final refreshCompleter = Completer<GitHubDownloadProxyConfigSnapshot>();
    final repository = _FakeRepository(refreshCompleter: refreshCompleter);
    final container = _container(repository);
    addTearDown(container.dispose);
    await _pumpPage(tester, container);

    await tester.tap(
      find.byKey(const ValueKey<String>('github-download-acceleration-switch')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('github-download-proxy-primary')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('refresh-github-proxy-list')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('github-download-proxy-secondary')),
    );
    await tester.pump();

    refreshCompleter.complete(
      _snapshot(<GitHubDownloadProxy>[
        const GitHubDownloadProxy(
          id: 'secondary',
          name: 'Secondary Proxy',
          urlPrefix: 'https://secondary.example.com/',
          enabled: true,
        ),
      ], refreshedAt: DateTime.parse('2026-07-27T12:00:00Z')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(
      container.read(appConfigProvider).githubDownloadProxyId,
      'secondary',
    );
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('failed initial load shows inline retry', (tester) async {
    final repository = _FakeRepository(loadError: StateError('load failed'));
    final container = _container(repository);
    addTearDown(container.dispose);

    await _pumpPage(tester, container);

    expect(find.text('加速服务列表加载失败'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '重试'), findsOneWidget);
    expect(repository.refreshCalls, 0);
  });
}

ProviderContainer _container(_FakeRepository repository) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      gitHubDownloadProxyRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

Future<void> _pumpPage(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const GitHubDownloadAccelerationPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;
}

class _FakeRepository implements GitHubDownloadProxyRepository {
  _FakeRepository({this.loadError, this.refreshCompleter});

  final Object? loadError;
  final Completer<GitHubDownloadProxyConfigSnapshot>? refreshCompleter;
  int loadCalls = 0;
  int refreshCalls = 0;

  @override
  Future<GitHubDownloadProxyConfigSnapshot> loadLocal() async {
    loadCalls += 1;
    final loadError = this.loadError;
    if (loadError != null) {
      throw loadError;
    }
    return _snapshot(<GitHubDownloadProxy>[
      const GitHubDownloadProxy(
        id: 'primary',
        name: 'Primary Proxy',
        urlPrefix: 'https://primary.example.com/',
        enabled: true,
      ),
      const GitHubDownloadProxy(
        id: 'secondary',
        name: 'Secondary Proxy With A Long Name',
        urlPrefix: 'https://secondary.example.com/path/',
        enabled: true,
      ),
    ]);
  }

  @override
  Future<GitHubDownloadProxyConfigSnapshot> refresh() async {
    refreshCalls += 1;
    final refreshCompleter = this.refreshCompleter;
    if (refreshCompleter != null) {
      return refreshCompleter.future;
    }
    return _snapshot(<GitHubDownloadProxy>[
      const GitHubDownloadProxy(
        id: 'remote',
        name: 'Remote Proxy',
        urlPrefix: 'https://remote.example.com/',
        enabled: true,
      ),
    ], refreshedAt: DateTime.parse('2026-07-27T12:00:00Z'));
  }
}

GitHubDownloadProxyConfigSnapshot _snapshot(
  List<GitHubDownloadProxy> proxies, {
  DateTime? refreshedAt,
}) {
  return GitHubDownloadProxyConfigSnapshot(
    config: GitHubDownloadProxyConfig(
      schemaVersion: 1,
      revision: 1,
      defaultProxyId: proxies.isEmpty ? null : proxies.first.id,
      proxies: proxies,
    ),
    refreshedAt: refreshedAt,
  );
}
