import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/update/data/github_release_api_client.dart';

void main() {
  test('fetchReleases sends pagination and decodes release bodies', () async {
    final adapter = _CapturingAdapter(
      body: '[{"tag_name":"v1.2.0","body":"notes"}]',
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.github.com'))
      ..httpClientAdapter = adapter;
    final result = await GitHubReleaseApiClient(
      dio,
    ).fetchReleases(owner: 'he music', repo: 'flutter/app', page: 3);
    expect(adapter.options?.path, '/repos/he%20music/flutter%2Fapp/releases');
    expect(adapter.options?.queryParameters, {'page': 3, 'per_page': 30});
    expect(result.single['body'], 'notes');
  });

  test('fetchDownloadProxyConfig requests raw repository config', () async {
    final adapter = _CapturingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.github.com'))
      ..httpClientAdapter = adapter;
    final client = GitHubReleaseApiClient(dio);

    final result = await client.fetchDownloadProxyConfig(
      owner: 'he music',
      repo: 'flutter/app',
    );

    expect(result, '{"schema_version":1,"revision":1,"proxies":[]}');
    expect(
      adapter.options?.path,
      '/repos/he%20music/flutter%2Fapp/contents/gh-proxy.json',
    );
    expect(
      adapter.options?.headers['Accept'],
      'application/vnd.github.raw+json',
    );
    expect(adapter.options?.responseType, ResponseType.plain);
  });
}

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter({
    this.body = '{"schema_version":1,"revision":1,"proxies":[]}',
  });

  final String body;
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromBytes(
      utf8.encode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
