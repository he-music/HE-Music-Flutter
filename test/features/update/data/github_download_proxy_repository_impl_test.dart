import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/update/data/github_download_proxy_config_data_source.dart';
import 'package:he_music_flutter/features/update/data/github_download_proxy_repository_impl.dart';
import 'package:he_music_flutter/features/update/data/github_release_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('valid refresh replaces the local snapshot', () async {
    final dataSource = GitHubDownloadProxyConfigDataSource(
      assetBundle: _StringAssetBundle(_config('bundled')),
    );
    final repository = GitHubDownloadProxyRepositoryImpl(
      apiClient: _FakeApiClient(_config('remote')),
      dataSource: dataSource,
      owner: 'owner',
      repo: 'repo',
      now: () => DateTime.parse('2026-07-27T12:00:00Z'),
    );

    final refreshed = await repository.refresh();
    final loaded = await repository.loadLocal();

    expect(refreshed.config.proxies.single.id, 'remote');
    expect(loaded.config.proxies.single.id, 'remote');
    expect(loaded.refreshedAt, DateTime.parse('2026-07-27T12:00:00Z'));
  });

  test('invalid refresh leaves the previous cache unchanged', () async {
    final dataSource = GitHubDownloadProxyConfigDataSource(
      assetBundle: _StringAssetBundle(_config('bundled')),
    );
    final validRepository = GitHubDownloadProxyRepositoryImpl(
      apiClient: _FakeApiClient(_config('cached')),
      dataSource: dataSource,
      owner: 'owner',
      repo: 'repo',
    );
    await validRepository.refresh();
    final invalidRepository = GitHubDownloadProxyRepositoryImpl(
      apiClient: _FakeApiClient('{invalid'),
      dataSource: dataSource,
      owner: 'owner',
      repo: 'repo',
    );

    await expectLater(invalidRepository.refresh(), throwsFormatException);
    final loaded = await invalidRepository.loadLocal();

    expect(loaded.config.proxies.single.id, 'cached');
  });

  test('network failure leaves the previous cache unchanged', () async {
    final dataSource = GitHubDownloadProxyConfigDataSource(
      assetBundle: _StringAssetBundle(_config('bundled')),
    );
    final validRepository = GitHubDownloadProxyRepositoryImpl(
      apiClient: _FakeApiClient(_config('cached')),
      dataSource: dataSource,
      owner: 'owner',
      repo: 'repo',
    );
    await validRepository.refresh();
    final failingRepository = GitHubDownloadProxyRepositoryImpl(
      apiClient: _FakeApiClient('', error: StateError('network failed')),
      dataSource: dataSource,
      owner: 'owner',
      repo: 'repo',
    );

    await expectLater(failingRepository.refresh(), throwsStateError);
    final loaded = await failingRepository.loadLocal();

    expect(loaded.config.proxies.single.id, 'cached');
  });

  test('lower remote revision does not replace the current config', () async {
    final dataSource = GitHubDownloadProxyConfigDataSource(
      assetBundle: _StringAssetBundle(_config('bundled', revision: 2)),
    );
    final repository = GitHubDownloadProxyRepositoryImpl(
      apiClient: _FakeApiClient(_config('remote', revision: 1)),
      dataSource: dataSource,
      owner: 'owner',
      repo: 'repo',
      now: () => DateTime.parse('2026-07-27T12:00:00Z'),
    );

    final refreshed = await repository.refresh();
    final loaded = await repository.loadLocal();

    expect(refreshed.config.proxies.single.id, 'bundled');
    expect(refreshed.refreshedAt, isNull);
    expect(loaded.config.proxies.single.id, 'bundled');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('update.github_download_proxy_config.v1'), isNull);
  });
}

String _config(String id, {int revision = 1}) =>
    '''
  {
    "schema_version": 1,
    "revision": $revision,
    "default_proxy_id": "$id",
    "proxies": [
      {
        "id": "$id",
        "name": "$id",
        "url_prefix": "https://$id.example.com/",
        "enabled": true
      }
    ]
  }
''';

class _FakeApiClient extends GitHubReleaseApiClient {
  _FakeApiClient(this.value, {this.error}) : super(Dio());

  final String value;
  final Object? error;

  @override
  Future<String> fetchDownloadProxyConfig({
    required String owner,
    required String repo,
  }) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return value;
  }
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.value);

  final String value;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.sublistView(bytes);
  }
}
