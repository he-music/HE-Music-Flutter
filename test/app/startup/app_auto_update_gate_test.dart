import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/startup/app_auto_update_gate.dart';
import 'package:he_music_flutter/features/update/application/update_download_target_service.dart';
import 'package:he_music_flutter/features/update/application/github_download_proxy_auto_refresh_service.dart';
import 'package:he_music_flutter/features/update/domain/entities/github_download_proxy_config.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release_asset.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_state.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_version.dart';
import 'package:he_music_flutter/features/update/presentation/controllers/update_controller.dart';
import 'package:he_music_flutter/features/update/presentation/providers/update_providers.dart';

void main() {
  testWidgets(
    'proxy refresh runs in background without blocking update check',
    (tester) async {
      final refreshCompleter = Completer<GitHubDownloadProxyConfigSnapshot>();
      var refreshCalls = 0;
      final autoRefreshService = GitHubDownloadProxyAutoRefreshService(
        isAndroid: () => true,
        loadLocal: () async => _proxySnapshot(),
        refresh: () {
          refreshCalls += 1;
          return refreshCompleter.future;
        },
      );
      final container = ProviderContainer(
        overrides: [
          appConfigDataSourceProvider.overrideWithValue(
            const _FakeAppConfigDataSource(
              autoCheckUpdates: true,
              githubDownloadAccelerationEnabled: true,
              githubDownloadProxyAutoUpdateEnabled: true,
            ),
          ),
          gitHubDownloadProxyAutoRefreshServiceProvider.overrideWithValue(
            autoRefreshService,
          ),
          updateControllerProvider.overrideWith(_CountingUpdateController.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: AppAutoUpdateGate(child: const SizedBox.shrink()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final controller =
          container.read(updateControllerProvider.notifier)
              as _CountingUpdateController;
      expect(refreshCalls, 1);
      expect(controller.checkCount, 1);

      refreshCompleter.complete(_proxySnapshot(refreshed: true));
      await tester.pump();
    },
  );

  testWidgets('proxy refresh failure is silent and update check continues', (
    tester,
  ) async {
    final autoRefreshService = GitHubDownloadProxyAutoRefreshService(
      isAndroid: () => true,
      loadLocal: () async => _proxySnapshot(),
      refresh: () async => throw StateError('refresh failed'),
    );
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(
          const _FakeAppConfigDataSource(
            autoCheckUpdates: true,
            githubDownloadAccelerationEnabled: true,
            githubDownloadProxyAutoUpdateEnabled: true,
          ),
        ),
        gitHubDownloadProxyAutoRefreshServiceProvider.overrideWithValue(
          autoRefreshService,
        ),
        updateControllerProvider.overrideWith(_CountingUpdateController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AppAutoUpdateGate(child: const SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final controller =
        container.read(updateControllerProvider.notifier)
            as _CountingUpdateController;
    expect(controller.checkCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app auto update gate checks once when enabled', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(
          _FakeAppConfigDataSource(autoCheckUpdates: true),
        ),
        updateControllerProvider.overrideWith(_CountingUpdateController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AppAutoUpdateGate(child: const SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final controller =
        container.read(updateControllerProvider.notifier)
            as _CountingUpdateController;
    expect(controller.checkCount, 1);
  });

  testWidgets('app auto update gate skips check when disabled', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(
          _FakeAppConfigDataSource(autoCheckUpdates: false),
        ),
        updateControllerProvider.overrideWith(_CountingUpdateController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AppAutoUpdateGate(child: const SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final controller =
        container.read(updateControllerProvider.notifier)
            as _CountingUpdateController;
    expect(controller.checkCount, 0);
  });

  testWidgets('app auto update gate shows available release sheet', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(
          _FakeAppConfigDataSource(autoCheckUpdates: true),
        ),
        updateControllerProvider.overrideWith(_AvailableUpdateController.new),
        updateDownloadTargetServiceProvider.overrideWithValue(
          _nonAndroidDownloadTargetService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: AppAutoUpdateGate(
            navigatorKey: navigatorKey,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('1.1.0'), findsOneWidget);
    expect(find.text('前往 GitHub Release'), findsOneWidget);
  });

  testWidgets('app auto update gate can show sheet with external navigator', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final container = ProviderContainer(
      overrides: [
        appConfigDataSourceProvider.overrideWithValue(
          _FakeAppConfigDataSource(autoCheckUpdates: true),
        ),
        updateControllerProvider.overrideWith(_AvailableUpdateController.new),
        updateDownloadTargetServiceProvider.overrideWithValue(
          _nonAndroidDownloadTargetService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Column(
            children: <Widget>[
              Expanded(
                child: Navigator(
                  key: navigatorKey,
                  onGenerateRoute: (settings) {
                    return MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: SizedBox.shrink()),
                    );
                  },
                ),
              ),
              AppAutoUpdateGate(
                navigatorKey: navigatorKey,
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
  });

  testWidgets(
    'Android update sheet uses shared APK target without refreshing proxies',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      var proxyLoads = 0;
      final downloadTargetService = UpdateDownloadTargetService(
        isAndroid: () => true,
        loadSupportedAbis: () async => const <String>['arm64-v8a'],
        loadProxyConfig: () async {
          proxyLoads += 1;
          return GitHubDownloadProxyConfigSnapshot(
            config: GitHubDownloadProxyConfig(
              schemaVersion: 1,
              revision: 1,
              defaultProxyId: null,
              proxies: const <GitHubDownloadProxy>[],
            ),
          );
        },
        owner: 'owner',
        repo: 'repo',
      );
      final container = ProviderContainer(
        overrides: [
          appConfigDataSourceProvider.overrideWithValue(
            _FakeAppConfigDataSource(autoCheckUpdates: true),
          ),
          updateControllerProvider.overrideWith(_AvailableUpdateController.new),
          updateDownloadTargetServiceProvider.overrideWithValue(
            downloadTargetService,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: AppAutoUpdateGate(
              navigatorKey: navigatorKey,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('下载更新'), findsOneWidget);
      expect(find.byTooltip('查看 GitHub Release'), findsOneWidget);
      expect(find.text('前往 GitHub Release'), findsNothing);
      expect(proxyLoads, 0);
    },
  );
}

class _FakeAppConfigDataSource extends AppConfigDataSource {
  const _FakeAppConfigDataSource({
    required this.autoCheckUpdates,
    this.githubDownloadAccelerationEnabled = false,
    this.githubDownloadProxyAutoUpdateEnabled = true,
  });

  final bool autoCheckUpdates;
  final bool githubDownloadAccelerationEnabled;
  final bool githubDownloadProxyAutoUpdateEnabled;

  @override
  Future<AppConfigState> load() async {
    return AppConfigState.initial.copyWith(
      autoCheckUpdates: autoCheckUpdates,
      githubDownloadAccelerationEnabled: githubDownloadAccelerationEnabled,
      githubDownloadProxyAutoUpdateEnabled:
          githubDownloadProxyAutoUpdateEnabled,
    );
  }
}

GitHubDownloadProxyConfigSnapshot _proxySnapshot({bool refreshed = false}) {
  return GitHubDownloadProxyConfigSnapshot(
    config: GitHubDownloadProxyConfig(
      schemaVersion: 1,
      revision: 1,
      defaultProxyId: null,
      proxies: const <GitHubDownloadProxy>[],
    ),
    refreshedAt: refreshed ? DateTime.parse('2026-07-28T12:00:00Z') : null,
  );
}

UpdateDownloadTargetService _nonAndroidDownloadTargetService() {
  return UpdateDownloadTargetService(
    isAndroid: () => false,
    loadSupportedAbis: () async => throw StateError('should not load ABI'),
    loadProxyConfig: () async => throw StateError('should not load proxies'),
    owner: 'owner',
    repo: 'repo',
  );
}

class _CountingUpdateController extends UpdateController {
  int checkCount = 0;

  @override
  UpdateState build() {
    return UpdateState.initial;
  }

  @override
  Future<void> checkForUpdates() async {
    checkCount += 1;
  }
}

class _AvailableUpdateController extends UpdateController {
  @override
  UpdateState build() {
    return UpdateState.initial;
  }

  @override
  Future<void> checkForUpdates() async {
    state = UpdateState(
      status: UpdateStatus.available,
      release: UpdateRelease(
        version: UpdateVersion.parse('1.1.0'),
        versionTag: 'v1.1.0',
        title: 'v1.1.0',
        releaseNotes: '更新内容',
        htmlUrl: 'https://example.com/release',
        publishedAt: DateTime(2026, 4, 24, 12),
        assets: const <UpdateReleaseAsset>[
          UpdateReleaseAsset(
            name: 'HE-Music-v1.1.0-android-arm64-v8a.apk',
            browserDownloadUrl:
                'https://github.com/owner/repo/releases/download/v1.1.0/HE-Music-v1.1.0-android-arm64-v8a.apk',
          ),
        ],
      ),
    );
  }
}
