import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/update/data/github_download_proxy_config_data_source.dart';
import 'package:he_music_flutter/features/update/domain/entities/github_download_proxy_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads bundled config when no valid cache exists', () async {
    final dataSource = GitHubDownloadProxyConfigDataSource(
      assetBundle: _StringAssetBundle(_config('bundled')),
    );

    final snapshot = await dataSource.loadLocal();

    expect(snapshot.config.proxies.single.id, 'bundled');
    expect(snapshot.refreshedAt, isNull);
  });

  test('loads cached config when its revision is newer', () async {
    final cached = GitHubDownloadProxyConfigSnapshot(
      config: GitHubDownloadProxyConfig.fromJsonString(
        _config('cached', revision: 2),
      ),
      refreshedAt: DateTime.parse('2026-07-27T12:00:00Z'),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'update.github_download_proxy_config.v1': cached.toCacheJsonString(),
    });
    final dataSource = GitHubDownloadProxyConfigDataSource(
      assetBundle: _StringAssetBundle(_config('bundled', revision: 1)),
    );

    final snapshot = await dataSource.loadLocal();

    expect(snapshot.config.proxies.single.id, 'cached');
    expect(snapshot.refreshedAt, isNotNull);
  });

  test('loads bundled config when its revision is newer', () async {
    final cached = GitHubDownloadProxyConfigSnapshot(
      config: GitHubDownloadProxyConfig.fromJsonString(
        _config('cached', revision: 1),
      ),
      refreshedAt: DateTime.parse('2026-07-27T12:00:00Z'),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'update.github_download_proxy_config.v1': cached.toCacheJsonString(),
    });
    final dataSource = GitHubDownloadProxyConfigDataSource(
      assetBundle: _StringAssetBundle(_config('bundled', revision: 2)),
    );

    final snapshot = await dataSource.loadLocal();

    expect(snapshot.config.proxies.single.id, 'bundled');
    expect(snapshot.refreshedAt, isNull);
  });

  test('prefers cached config when revisions are equal', () async {
    final cached = GitHubDownloadProxyConfigSnapshot(
      config: GitHubDownloadProxyConfig.fromJsonString(_config('cached')),
      refreshedAt: DateTime.parse('2026-07-27T12:00:00Z'),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'update.github_download_proxy_config.v1': cached.toCacheJsonString(),
    });
    final dataSource = GitHubDownloadProxyConfigDataSource(
      assetBundle: _StringAssetBundle(_config('bundled')),
    );

    final snapshot = await dataSource.loadLocal();

    expect(snapshot.config.proxies.single.id, 'cached');
    expect(snapshot.refreshedAt, isNotNull);
  });

  test('falls back to bundled config when cache is damaged', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'update.github_download_proxy_config.v1': '{invalid',
    });
    final dataSource = GitHubDownloadProxyConfigDataSource(
      assetBundle: _StringAssetBundle(_config('bundled')),
    );

    final snapshot = await dataSource.loadLocal();
    final prefs = await SharedPreferences.getInstance();

    expect(snapshot.config.proxies.single.id, 'bundled');
    expect(
      prefs.getString('update.github_download_proxy_config.v1'),
      '{invalid',
    );
  });

  test('saves config and refresh time in one cache value', () async {
    final dataSource = GitHubDownloadProxyConfigDataSource(
      assetBundle: _StringAssetBundle(_config('bundled')),
    );
    final snapshot = GitHubDownloadProxyConfigSnapshot(
      config: GitHubDownloadProxyConfig.fromJsonString(_config('remote')),
      refreshedAt: DateTime.parse('2026-07-27T12:00:00Z'),
    );

    await dataSource.save(snapshot);
    final loaded = await dataSource.loadLocal();

    expect(loaded.config.proxies.single.id, 'remote');
    expect(loaded.refreshedAt, DateTime.parse('2026-07-27T12:00:00Z'));
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

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.value);

  final String value;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.sublistView(bytes);
  }
}
