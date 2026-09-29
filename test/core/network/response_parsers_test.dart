import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/core/error/failure.dart';
import 'package:he_music_flutter/core/network/response_parsers.dart';

void main() {
  group('parseResponseMap', () {
    test('preserves an existing string-keyed map and nested values', () {
      final nested = <int, String>{1: 'value'};
      final payload = <String, dynamic>{'nested': nested};

      expect(parseResponseMap(payload), same(payload));
      expect(parseResponseMap(payload)['nested'], same(nested));
    });

    test('converts map keys to strings without changing values', () {
      final value = Object();
      final payload = <Object?, Object?>{1: value, null: false};

      final parsed = parseResponseMap(payload);

      expect(parsed.keys, ['1', 'null']);
      expect(parsed['1'], same(value));
      expect(parsed['null'], isFalse);
    });

    test('keeps the last value when converted keys collide', () {
      expect(parseResponseMap(<Object, String>{1: 'first', '1': 'last'}), {
        '1': 'last',
      });
    });

    test('rejects non-map payloads with the original network error', () {
      for (final value in <Object?>[null, 1, 'invalid', <Object>[]]) {
        expect(
          () => parseResponseMap(value),
          throwsA(
            isA<AppException>().having(
              (error) => error.failure,
              'failure',
              isA<NetworkFailure>().having(
                (failure) => failure.message,
                'message',
                'Invalid payload type: ${value.runtimeType}',
              ),
            ),
          ),
        );
      }
    });
  });

  group('parseResponseBool', () {
    test('recognizes booleans, numbers and normalized boolean strings', () {
      final cases = <(Object, bool)>[
        (true, true),
        (false, false),
        (0, false),
        (-0.0, false),
        (1, true),
        (-2, true),
        (0.5, true),
        (double.nan, true),
        (' TRUE ', true),
        (' false ', false),
        ('1', true),
        ('0', false),
      ];
      for (final (value, expected) in cases) {
        expect(
          parseResponseBool(value, fallback: !expected),
          expected,
          reason: 'value: $value',
        );
      }
    });

    test('uses the caller fallback for unrecognized values', () {
      for (final fallback in [false, true]) {
        for (final value in <Object?>[null, '', 'yes', '2', [], {}]) {
          expect(parseResponseBool(value, fallback: fallback), fallback);
        }
      }
    });
  });
}
