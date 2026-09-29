import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/core/captcha/captcha_challenge.dart';
import 'package:he_music_flutter/core/captcha/captcha_coordinator.dart';
import 'package:he_music_flutter/core/network/captcha_challenge_interceptor.dart';

void main() {
  for (final retryReason in <String?>[
    null,
    'CAPTCHA_REQUIRED',
    'CAPTCHA_INVALID',
  ]) {
    test(
      'adds ticket only once; retry reason $retryReason is not replayed',
      () async {
        final adapter = _LoginAdapter(retryReason);
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter;
        final coordinator = _TicketCoordinator();
        dio.interceptors.add(
          CaptchaChallengeInterceptor(dio: dio, coordinator: coordinator),
        );

        final request = dio.post<dynamic>(
          '/v1/user/login',
          data: <String, dynamic>{'username': 'alice', 'password': 'secret'},
        );
        if (retryReason == null) {
          expect((await request).statusCode, 200);
        } else {
          await expectLater(request, throwsA(isA<DioException>()));
        }
        expect(coordinator.opens, 1);
        expect(adapter.bodies, [
          {'username': 'alice', 'password': 'secret'},
          {
            'username': 'alice',
            'password': 'secret',
            'captcha_ticket': 'ticket-1',
          },
        ]);
        dio.close();
      },
    );
  }
}

class _TicketCoordinator extends CaptchaCoordinator {
  _TicketCoordinator() : super(GoRouter(routes: []));

  int opens = 0;

  @override
  Future<String?> open(CaptchaChallenge challenge) async {
    opens++;
    expect(challenge.scene, '1');
    expect(challenge.meta, 'alice');
    return 'ticket-1';
  }
}

class _LoginAdapter implements HttpClientAdapter {
  _LoginAdapter(this.retryReason);

  final String? retryReason;
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    bodies.add(Map<String, dynamic>.from(options.data as Map));
    final reason = bodies.length == 1 ? 'CAPTCHA_REQUIRED' : retryReason;
    return ResponseBody.fromString(
      jsonEncode(
        reason == null
            ? <String, dynamic>{'ok': true}
            : <String, dynamic>{
                'reason': reason,
                'metadata': {'scene': 1, 'meta': 'alice'},
              },
      ),
      reason == null ? 200 : 403,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
