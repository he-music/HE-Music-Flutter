import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/update/data/github_release_api_client.dart';

void main() {
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
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromBytes(
      utf8.encode('{"schema_version":1,"revision":1,"proxies":[]}'),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
