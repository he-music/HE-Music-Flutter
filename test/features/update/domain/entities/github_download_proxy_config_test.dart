import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/update/domain/entities/github_download_proxy_config.dart';

void main() {
  test('parses valid config and normalizes the URL prefix', () {
    final config = GitHubDownloadProxyConfig.fromJsonString('''
      {
        "schema_version": 1,
        "revision": 2,
        "default_proxy_id": "primary",
        "proxies": [
          {
            "id": "primary",
            "name": "Primary",
            "url_prefix": "https://proxy.example.com/path",
            "enabled": true
          }
        ]
      }
    ''');

    expect(config.schemaVersion, 1);
    expect(config.revision, 2);
    expect(config.proxies.single.urlPrefix, 'https://proxy.example.com/path/');
    expect(config.resolveProxy(null)?.id, 'primary');
  });

  test('rejects non-integer and unsupported schema versions', () {
    expect(
      () => GitHubDownloadProxyConfig.fromJsonString(
        '{"schema_version":1.0,"revision":1,"proxies":[]}',
      ),
      throwsFormatException,
    );
    expect(
      () => GitHubDownloadProxyConfig.fromJsonString(
        '{"schema_version":2,"revision":1,"proxies":[]}',
      ),
      throwsFormatException,
    );
  });

  test('rejects missing, non-integer, and non-positive revisions', () {
    for (final json in <String>[
      '{"schema_version":1,"proxies":[]}',
      '{"schema_version":1,"revision":1.0,"proxies":[]}',
      '{"schema_version":1,"revision":0,"proxies":[]}',
      '{"schema_version":1,"revision":-1,"proxies":[]}',
    ]) {
      expect(
        () => GitHubDownloadProxyConfig.fromJsonString(json),
        throwsFormatException,
      );
    }
  });

  test('rejects HTTP, credential, query, and duplicate id configs', () {
    for (final url in <String>[
      'http://proxy.example.com/',
      'https://user:pass@proxy.example.com/',
      'https://proxy.example.com/?token=value',
    ]) {
      expect(
        () => GitHubDownloadProxyConfig.fromJsonString(
          _configWithProxies(<String>[_proxy('same', url)]),
        ),
        throwsFormatException,
      );
    }
    expect(
      () => GitHubDownloadProxyConfig.fromJsonString(
        _configWithProxies(<String>[
          _proxy('same', 'https://one.example.com/'),
          _proxy('same', 'https://two.example.com/'),
        ]),
      ),
      throwsFormatException,
    );
  });

  test('resolves selected, recommended, and first enabled proxy in order', () {
    final config = GitHubDownloadProxyConfig.fromJsonString('''
      {
        "schema_version": 1,
        "revision": 1,
        "default_proxy_id": "disabled",
        "proxies": [
          ${_proxy('disabled', 'https://disabled.example.com/', enabled: false)},
          ${_proxy('first', 'https://first.example.com/')},
          ${_proxy('selected', 'https://selected.example.com/')}
        ]
      }
    ''');

    expect(config.resolveProxy('selected')?.id, 'selected');
    expect(config.resolveProxy('removed')?.id, 'first');
    expect(config.enabledProxies.map((proxy) => proxy.id), <String>[
      'first',
      'selected',
    ]);
  });

  test('allows an empty list to disable every proxy', () {
    final config = GitHubDownloadProxyConfig.fromJsonString(
      '{"schema_version":1,"revision":1,"default_proxy_id":"missing","proxies":[]}',
    );

    expect(config.enabledProxies, isEmpty);
    expect(config.resolveProxy(null), isNull);
  });

  test('cache snapshot preserves config and refresh time', () {
    final snapshot = GitHubDownloadProxyConfigSnapshot(
      config: GitHubDownloadProxyConfig.fromJsonString(
        _configWithProxies(<String>[
          _proxy('primary', 'https://proxy.example.com/'),
        ]),
      ),
      refreshedAt: DateTime.parse('2026-07-27T12:00:00Z'),
    );

    final decoded = GitHubDownloadProxyConfigSnapshot.fromCacheJsonString(
      snapshot.toCacheJsonString(),
    );

    expect(decoded.refreshedAt, DateTime.parse('2026-07-27T12:00:00Z'));
    expect(decoded.config.revision, 1);
    expect(decoded.config.proxies.single.id, 'primary');
  });
}

String _configWithProxies(List<String> proxies) =>
    '''
  {
    "schema_version": 1,
    "revision": 1,
    "default_proxy_id": "primary",
    "proxies": [${proxies.join(',')}]
  }
''';

String _proxy(String id, String url, {bool enabled = true}) =>
    '''
  {
    "id": "$id",
    "name": "$id",
    "url_prefix": "$url",
    "enabled": $enabled
  }
''';
