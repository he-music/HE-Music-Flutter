import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/decrypt/audio_transform_parameters.dart';

String _encode(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');

void main() {
  test('matches Go json/v2 Unicode, unsigned and byte-string edge cases', () {
    for (final member in [
      r'"user_agent":"\ud800"',
      r'"user_agent":"\udc00"',
      r'"unknown":"\ud800"',
      r'"\ud800":0',
      r'"hash":-0',
      r'"hash":-1',
      r'"hash":4294967296',
      r'"unknown":{"a":1,"\u0061":2}',
    ]) {
      expect(
        () => AudioTransformParameters.parse(
          _encode('{"v":1,"kind":1,"key":"AQ==",$member}'),
        ),
        throwsFormatException,
        reason: member,
      );
    }
    for (final key in [r'AQ==\n', r'AQ==\r', 'AQ', '_w==']) {
      expect(
        () => AudioTransformParameters.parse(
          _encode('{"v":1,"kind":1,"key":"$key"}'),
        ),
        throwsFormatException,
      );
    }
    // Go json/v2 uses non-strict inner Base64: unused tail bits are tolerated.
    final p = AudioTransformParameters.parse(
      _encode(
        r'{"v":1,"kind":1,"key":"AR==","HASH":1,"user_agent":"\ud83c\udfb5"}',
      ),
    );
    expect(p.key, [1]);
    expect(p.hash, 0); // Field matching is case sensitive.
    expect(p.userAgent, '🎵');
  });

  test(
    'matches Go strict raw Base64URL, including CR/LF transport handling',
    () {
      final valid = _encode('{"v":1,"kind":1,"key":"AQ=="}');
      expect(AudioTransformParameters.parse('$valid\r\n').kind, 1);
      expect(
        AudioTransformParameters.parse(
          '${valid.substring(0, 3)}\r\n${valid.substring(3)}',
        ).kind,
        1,
      );
      for (final invalid in [
        '$valid=',
        '$valid ',
        '\r\n',
        '${valid.substring(0, valid.length - 1)}1',
      ]) {
        expect(
          () => AudioTransformParameters.parse(invalid),
          throwsFormatException,
        );
      }
    },
  );
}
