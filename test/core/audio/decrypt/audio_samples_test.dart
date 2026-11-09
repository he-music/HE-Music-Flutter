import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/decrypt/audio_decryptor.dart';
import 'package:he_music_flutter/core/audio/decrypt/audio_transform_parameters.dart';

Uint8List _hex(String text) => Uint8List.fromList([
  for (var i = 0; i < text.length; i += 2)
    int.parse(text.substring(i, i + 2), radix: 16),
]);
Uint8List _box(String type, List<int> body) {
  final out = Uint8List(8 + body.length);
  ByteData.sublistView(out).setUint32(0, out.length);
  out.setRange(4, 8, ascii.encode(type));
  out.setRange(8, out.length, body);
  return out;
}

void main() {
  final vectors =
      jsonDecode(
            File(
              'test/core/audio/decrypt/fixtures/go_vectors.json',
            ).readAsStringSync(),
          )
          as List;
  final vector = (vectors.cast<Map<String, dynamic>>()).firstWhere(
    (v) => v['ivSize'] == 16 && v['subsamples'] == false,
  );
  final original = _hex(vector['input'] as String);
  final expected = _hex(vector['output'] as String);
  final p = AudioTransformParameters.parse(vector['parameters'] as String);
  Uint8List body(Uint8List input, String type) {
    final at = latin1.decode(input).indexOf(type) - 4;
    final size = ByteData.sublistView(input).getUint32(at);
    return input.sublist(at + 8, at + size);
  }

  final encrypted = body(original, 'mdat');
  final plain = body(expected, 'mdat');
  final iv = body(original, 'senc').sublist(8);
  Uint8List fixture({
    bool fixed = false,
    bool malformedSubsamples = false,
    int depth = 0,
  }) {
    final sz = Uint8List(fixed ? 12 : 20);
    final d = ByteData.sublistView(sz);
    d.setUint32(8, 2);
    if (fixed) {
      d.setUint32(4, encrypted.length);
    } else {
      d.setUint32(12, encrypted.length);
      d.setUint32(16, encrypted.length);
    }
    final senc = Uint8List(8 + iv.length * 2);
    ByteData.sublistView(senc).setUint32(4, 2);
    senc.setRange(8, 8 + iv.length, iv);
    senc.setRange(8 + iv.length, senc.length, iv);
    if (malformedSubsamples) senc[3] = 2;
    var stbl = _box('stbl', [
      ..._box('stsd', body(original, 'stsd')),
      ..._box('stsz', sz),
      ..._box('senc', senc),
    ]);
    for (var i = 0; i < depth; i++) {
      stbl = _box('trak', stbl);
    }
    return Uint8List.fromList([
      ..._box('moov', stbl),
      ..._box('mdat', [...encrypted, ...encrypted]),
    ]);
  }

  test('resets AES-CTR for each sample with fixed and variable stsz', () {
    for (final fixed in [false, true]) {
      final decoded = decryptAudioSamples(fixture(fixed: fixed), p);
      expect(body(decoded, 'mdat'), [...plain, ...plain]);
    }
  });
  test('rejects truncated subsample entries and excessive MP4 nesting', () {
    expect(
      () => decryptAudioSamples(fixture(malformedSubsamples: true), p),
      throwsFormatException,
    );
    expect(
      () => decryptAudioSamples(fixture(depth: 33), p),
      throwsFormatException,
    );
  });
  test('rejects stream transform parameters at sample entry', () {
    final stream = AudioTransformParameters.parse(
      base64Url
          .encode(utf8.encode('{"v":1,"kind":1,"key":"AQ=="}'))
          .replaceAll('=', ''),
    );
    expect(() => decryptAudioSamples(original, stream), throwsFormatException);
  });
}
