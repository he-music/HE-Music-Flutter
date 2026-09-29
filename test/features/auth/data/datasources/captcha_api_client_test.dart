import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/auth/data/datasources/captcha_api_client.dart';

void main() {
  test('creates an image session and refreshes the same session', () async {
    final adapter = _CaptchaAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    final client = CaptchaApiClient(dio);

    final first = await client.fetchCaptcha(scene: '1', meta: 'alice');
    expect(first.isSupported, isTrue);
    expect(first.sessionId, 'session-1');
    expect(first.challengeId, 'challenge-1');
    expect(adapter.requests.first.uri.queryParameters, {
      'scene': '1',
      'meta': 'alice',
      'supported_methods': '1',
    });

    final next = await client.fetchCaptcha(
      scene: '1',
      meta: 'alice',
      sessionId: first.sessionId,
    );
    expect(next.challengeId, 'challenge-2');
    expect(adapter.requests.last.uri.queryParameters, {
      'scene': '1',
      'meta': 'alice',
      'session_id': 'session-1',
    });
    dio.close();
  });

  test('submits current challenge and reads ticket from result', () async {
    final adapter = _CaptchaAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    final client = CaptchaApiClient(dio);

    final result = await client.verifyCaptcha(
      scene: '1',
      meta: 'alice',
      sessionId: 'session-1',
      challengeId: 'challenge-2',
      angle: 3,
    );
    expect(result.isSuccess, isTrue);
    expect(result.ticket, 'ticket-1');
    expect(adapter.bodies.single, {
      'scene': '1',
      'meta': 'alice',
      'session_id': 'session-1',
      'challenge_id': 'challenge-2',
      'angle': 3,
      'point': <String, dynamic>{},
      'dots': <Map<String, dynamic>>[],
    });

    final recovered = await client.getResult('session-1');
    expect(recovered.ticket, 'ticket-1');
    expect(adapter.requests.last.path, '/v1/captcha/result');
    expect(adapter.bodies.last, {'session_id': 'session-1'});
    dio.close();
  });
}

class _CaptchaAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <Map<String, dynamic>>[];
  var _challenge = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'POST') {
      bodies.add(Map<String, dynamic>.from(options.data as Map));
    }
    final response = options.method == 'GET'
        ? <String, dynamic>{
            'method': 1,
            'type': 5,
            'session_id': 'session-1',
            'challenge_id': 'challenge-${++_challenge}',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch,
            'image': 'image',
            'thumb': 'thumb',
          }
        : <String, dynamic>{'is_success': true, 'captcha_ticket': 'ticket-1'};
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
