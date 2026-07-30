import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/utils/in_flight_request_cache.dart';

void main() {
  test('同一 key 复用进行中请求，完成后允许重新请求', () async {
    final cache = InFlightRequestCache<String, int>();
    final firstRequest = Completer<int>();
    var calls = 0;

    final first = cache.run('a', () {
      calls += 1;
      return firstRequest.future;
    });
    final second = cache.run('a', () {
      calls += 1;
      return Future<int>.value(2);
    });

    expect(identical(first, second), isTrue);
    expect(calls, 1);

    firstRequest.complete(1);
    expect(await Future.wait<int>(<Future<int>>[first, second]), <int>[1, 1]);

    final refreshed = await cache.run('a', () async {
      calls += 1;
      return 3;
    });
    expect(refreshed, 3);
    expect(calls, 2);
  });

  test('请求失败后释放 key，允许重试发起新请求', () async {
    final cache = InFlightRequestCache<String, int>();
    var calls = 0;

    await expectLater(
      cache.run('a', () async {
        calls += 1;
        throw Exception('request failed');
      }),
      throwsException,
    );

    final result = await cache.run('a', () async {
      calls += 1;
      return 2;
    });

    expect(result, 2);
    expect(calls, 2);
  });
}
