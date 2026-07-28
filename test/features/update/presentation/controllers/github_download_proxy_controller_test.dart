import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/update/domain/entities/github_download_proxy_config.dart';
import 'package:he_music_flutter/features/update/domain/repositories/github_download_proxy_repository.dart';
import 'package:he_music_flutter/features/update/presentation/providers/update_providers.dart';

void main() {
  test('build only loads local config', () async {
    final repository = _FakeRepository();
    final container = ProviderContainer(
      overrides: [
        gitHubDownloadProxyRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final snapshot = await container.read(
      gitHubDownloadProxyControllerProvider.future,
    );

    expect(snapshot.config.proxies.single.id, 'local');
    expect(repository.loadCalls, 1);
    expect(repository.refreshCalls, 0);
  });

  test('refresh replaces state only after repository succeeds', () async {
    final repository = _FakeRepository();
    final container = ProviderContainer(
      overrides: [
        gitHubDownloadProxyRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(gitHubDownloadProxyControllerProvider.future);

    final refreshed = await container
        .read(gitHubDownloadProxyControllerProvider.notifier)
        .refresh();

    expect(refreshed.config.proxies.single.id, 'remote');
    expect(
      container
          .read(gitHubDownloadProxyControllerProvider)
          .requireValue
          .config
          .proxies
          .single
          .id,
      'remote',
    );
    expect(repository.refreshCalls, 1);
  });

  test('failed refresh keeps the previous state', () async {
    final repository = _FakeRepository(refreshError: StateError('failed'));
    final container = ProviderContainer(
      overrides: [
        gitHubDownloadProxyRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(gitHubDownloadProxyControllerProvider.future);

    await expectLater(
      container.read(gitHubDownloadProxyControllerProvider.notifier).refresh(),
      throwsStateError,
    );

    expect(
      container
          .read(gitHubDownloadProxyControllerProvider)
          .requireValue
          .config
          .proxies
          .single
          .id,
      'local',
    );
  });
}

class _FakeRepository implements GitHubDownloadProxyRepository {
  _FakeRepository({this.refreshError});

  final Object? refreshError;
  int loadCalls = 0;
  int refreshCalls = 0;

  @override
  Future<GitHubDownloadProxyConfigSnapshot> loadLocal() async {
    loadCalls += 1;
    return _snapshot('local');
  }

  @override
  Future<GitHubDownloadProxyConfigSnapshot> refresh() async {
    refreshCalls += 1;
    final refreshError = this.refreshError;
    if (refreshError != null) {
      throw refreshError;
    }
    return _snapshot('remote', refreshed: true);
  }
}

GitHubDownloadProxyConfigSnapshot _snapshot(
  String id, {
  bool refreshed = false,
}) {
  return GitHubDownloadProxyConfigSnapshot(
    config: GitHubDownloadProxyConfig(
      schemaVersion: 1,
      revision: 1,
      defaultProxyId: id,
      proxies: <GitHubDownloadProxy>[
        GitHubDownloadProxy(
          id: id,
          name: id,
          urlPrefix: 'https://$id.example.com/',
          enabled: true,
        ),
      ],
    ),
    refreshedAt: refreshed ? DateTime.parse('2026-07-27T12:00:00Z') : null,
  );
}
