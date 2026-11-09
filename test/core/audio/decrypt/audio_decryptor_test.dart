import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/decrypt/audio_decryptor.dart';
import 'package:he_music_flutter/core/audio/decrypt/audio_transform_parameters.dart';

String encode(Object value) => encodeText(jsonEncode(value));
String encodeText(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');
Uint8List hex(String value) => Uint8List.fromList([
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
]);
final vectors =
    (jsonDecode(
              File(
                'test/core/audio/decrypt/fixtures/go_vectors.json',
              ).readAsStringSync(),
            )
            as List)
        .cast<Map<String, dynamic>>();

void main() {
  group('AudioTransformParameters.parse', () {
    test(
      'accepts v1, unknown members, null optional members and prepared bytes',
      () {
        final p = AudioTransformParameters.parse(
          encode({
            'v': 1,
            'kind': 1,
            'key': 'AQc=',
            'user_agent': 'media agent',
            'box': null,
            'hash': null,
            'unknown': {
              'nested': [true, 1],
            },
          }),
        );
        expect(p.kind, 1);
        expect(p.key, [1, 7]);
        expect(p.userAgent, 'media agent');
        expect(() => p.key[0] = 0, throwsUnsupportedError);
      },
    );
    test(
      'rejects Go invalid parameter cases and strict transport encodings',
      () {
        final invalid = <String>[
          '',
          '!',
          'a' * 16385,
          encodeText('{"v":1,"v":1,"kind":1,"key":"AQ=="}'),
          encodeText('{"v":1,"kind":1,"key":"AQ==","unknown":{"a":1,"a":2}}'),
          encodeText('{"v":1.0,"kind":1,"key":"AQ=="}'),
          encodeText('{"v":1,"kind":1,"key":"AQ==","hash":1e0}'),
          encodeText('{"v":1,"kind":1,"key":"AQ==","user_agent":42}'),
          encodeText('[]'),
        ];
        final base = <String, Object?>{'v': 1, 'kind': 1, 'key': 'AQ=='};
        for (final change in <Map<String, Object?>>[
          {'v': 2},
          {'kind': 99},
          {'kind': 2, 'period': 0},
          {'key': ''},
          {'key': 'AQ'},
          {'key': '_w=='},
          {'key': base64.encode(List.filled(4097, 1))},
          {'kind': 3, 'box': 'AQ==', 'hash': 1, 'segment': 2, 'key': 'AA=='},
          {'kind': 3, 'box': 'AQI=', 'hash': 1, 'segment': 2},
          {'kind': 3, 'box': 'AQ==', 'hash': 1, 'segment': 2, 'first': 3},
          {'kind': 3, 'box': 'AQ==', 'hash': 0x100000000, 'segment': 2},
          {'kind': 4},
          {'box': 'AQ=='},
          {'first': 1},
          {'segment': 1},
          {'bias': 1},
          {'kind': 2, 'period': 1048577},
          {'kind': 2, 'period': 1, 'bias': -1},
          {'user_agent': 'bad\r\nheader'},
          {'user_agent': '\x00'},
          {'user_agent': '音' * 86},
        ]) {
          invalid.add(encode({...base, ...change}));
        }
        final valid = encode(base);
        invalid.addAll([
          '$valid=',
          '$valid ',
          '${valid.substring(0, valid.length - 1)}9',
        ]);
        for (final encoded in invalid) {
          expect(
            () => AudioTransformParameters.parse(encoded),
            throwsFormatException,
            reason: encoded,
          );
        }
      },
    );
    test('accepts all AES key sizes and validates per-kind upper bounds', () {
      for (final length in [16, 24, 32]) {
        expect(
          AudioTransformParameters.parse(
            encode({
              'v': 1,
              'kind': 4,
              'key': base64.encode(List.filled(length, 1)),
            }),
          ).kind,
          4,
        );
      }
      expect(
        AudioTransformParameters.parse(
          encode({
            'v': 1,
            'kind': 2,
            'key': 'AQ==',
            'period': 1 << 20,
            'bias': 1 << 20,
          }),
        ).period,
        1 << 20,
      );
    });
  });

  group('transformAudioBytes', () {
    for (final vector in vectors.where((v) => v.containsKey('offset'))) {
      final p = AudioTransformParameters.parse(vector['parameters'] as String);
      final offset = vector['offset'] as int;
      test(
        'matches Go kind ${p.kind}, absolute offset $offset and arbitrary chunks',
        () {
          final input = hex(vector['input'] as String);
          final original = Uint8List.fromList(input);
          final expected = hex(vector['output'] as String);
          expect(transformAudioBytes(input, p, offset: offset), expected);
          final chunks = BytesBuilder();
          var pos = 0;
          for (final count in [1, 3, 13, 17, 64, 159]) {
            chunks.add(
              transformAudioBytes(
                Uint8List.sublistView(input, pos, pos + count),
                p,
                offset: offset + pos,
              ),
            );
            pos += count;
          }
          expect(chunks.takeBytes(), expected);
          expect(input, original);
        },
      );
    }
    test('rejects invalid offsets, overflow and sample kind', () {
      final p = AudioTransformParameters.parse(
        vectors.first['parameters'] as String,
      );
      for (final offset in [-1, (1 << 40) + 1, 1 << 40]) {
        expect(
          () => transformAudioBytes(Uint8List(1), p, offset: offset),
          throwsFormatException,
        );
      }
      expect(transformAudioBytes(Uint8List(0), p, offset: 1 << 40), isEmpty);
      final sample = AudioTransformParameters.parse(
        vectors.last['parameters'] as String,
      );
      expect(
        () => transformAudioBytes(Uint8List(0), sample),
        throwsFormatException,
      );
    });
  });

  group('decryptAudioSamples', () {
    for (final vector in vectors.where((v) => v.containsKey('ivSize'))) {
      test(
        'matches Go IV ${vector['ivSize']}, subsamples ${vector['subsamples']}, ${vector['format']}',
        () {
          final input = hex(vector['input'] as String);
          final original = Uint8List.fromList(input);
          final p = AudioTransformParameters.parse(
            vector['parameters'] as String,
          );
          expect(
            decryptAudioSamples(input, p),
            hex(vector['output'] as String),
          );
          expect(input, original);
        },
      );
    }
    test(
      'rejects malformed box/table/sample bounds without mutating input',
      () {
        final vector = vectors.firstWhere((v) => v.containsKey('ivSize'));
        final original = hex(vector['input'] as String);
        final p = AudioTransformParameters.parse(
          vector['parameters'] as String,
        );
        final cases = <Uint8List>[
          Uint8List(0),
          Uint8List.fromList(utf8.encode('not an mp4')),
        ];
        for (final kind in ['moov', 'stsz', 'senc', 'mdat']) {
          final at = latin1.decode(original).indexOf(kind);
          final changed = Uint8List.fromList(original);
          ByteData.sublistView(changed).setUint32(at - 4, 0xffffffff);
          cases.add(changed);
        }
        final stsz = latin1.decode(original).indexOf('stsz');
        for (final size in [0, 1, 0xffffffff]) {
          final changed = Uint8List.fromList(original);
          ByteData.sublistView(changed).setUint32(stsz + 8, size);
          cases.add(changed);
        }
        final hugeCount = Uint8List.fromList(original);
        ByteData.sublistView(hugeCount).setUint32(stsz + 12, 0xffffffff);
        cases.add(hugeCount);
        for (final input in cases) {
          final before = Uint8List.fromList(input);
          expect(() => decryptAudioSamples(input, p), throwsFormatException);
          expect(input, before);
        }
      },
    );
    test(
      'supports extended and end-of-file box lengths and original-format fallback',
      () {
        final vector = vectors.firstWhere((v) => v.containsKey('ivSize'));
        final original = hex(vector['input'] as String);
        final p = AudioTransformParameters.parse(
          vector['parameters'] as String,
        );
        final mdat = latin1.decode(original).indexOf('mdat') - 4;
        final expected = hex(vector['output'] as String);
        final zero = Uint8List.fromList(original);
        ByteData.sublistView(zero).setUint32(mdat, 0);
        final zeroExpected = Uint8List.fromList(expected);
        ByteData.sublistView(zeroExpected).setUint32(mdat, 0);
        expect(decryptAudioSamples(zero, p), zeroExpected);
        Uint8List extended(Uint8List input) {
          final out = Uint8List(input.length + 8);
          out.setRange(0, mdat + 8, input);
          final d = ByteData.sublistView(out);
          d.setUint32(mdat, 1);
          d.setUint64(mdat + 8, input.length - mdat + 8);
          out.setRange(mdat + 16, out.length, input, mdat + 8);
          return out;
        }

        expect(decryptAudioSamples(extended(original), p), extended(expected));
        final fallback = Uint8List.fromList(original);
        final frma = latin1.decode(original).indexOf('frma');
        fallback[frma] = 0;
        expect(
          latin1.decode(decryptAudioSamples(fallback, p)),
          contains('mp4a'),
        );
      },
    );
  });

  group('decryptAudioFile', () {
    late Directory directory;
    setUp(() {
      directory = Directory.systemTemp.createTempSync('audio-decrypt-test-');
    });
    tearDown(() {
      directory.deleteSync(recursive: true);
    });
    test(
      'worker handles multiple chunks and atomically replaces complete output',
      () async {
        final input = File('${directory.path}/input');
        final output = File('${directory.path}/output')
          ..writeAsStringSync('old');
        final bytes = Uint8List.fromList(List.generate(150000, (i) => i & 255));
        input.writeAsBytesSync(bytes);
        for (final vector in vectors.where((v) => v['offset'] == 0)) {
          final encoded = vector['parameters'] as String;
          await decryptAudioFile(
            input: input,
            output: output,
            encodedParameters: encoded,
          );
          expect(
            output.readAsBytesSync(),
            transformAudioBytes(bytes, AudioTransformParameters.parse(encoded)),
          );
          expect(input.readAsBytesSync(), bytes);
        }
        expect(directory.listSync().length, 2);
      },
    );
    test(
      'worker decrypts complete MP4 and retains existing files on every failure',
      () async {
        final vector = vectors.last;
        final input = File('${directory.path}/input')
          ..writeAsBytesSync(hex(vector['input'] as String));
        final output = File('${directory.path}/output')
          ..writeAsStringSync('old');
        final encoded = vector['parameters'] as String;
        await decryptAudioFile(
          input: input,
          output: output,
          encodedParameters: encoded,
        );
        expect(output.readAsBytesSync(), hex(vector['output'] as String));
        for (final badParameters in ['invalid', encoded]) {
          input.writeAsStringSync('malformed mp4');
          output.writeAsStringSync('old');
          await expectLater(
            decryptAudioFile(
              input: input,
              output: output,
              encodedParameters: badParameters,
            ),
            throwsFormatException,
          );
          expect(input.readAsStringSync(), 'malformed mp4');
          expect(output.readAsStringSync(), 'old');
        }
        await expectLater(
          decryptAudioFile(
            input: input,
            output: input,
            encodedParameters: encoded,
          ),
          throwsA(isA<FileSystemException>()),
        );
        final alias = Link('${directory.path}/alias')..createSync(input.path);
        await expectLater(
          decryptAudioFile(
            input: input,
            output: File(alias.path),
            encodedParameters: encoded,
          ),
          throwsA(isA<FileSystemException>()),
        );
        await expectLater(
          decryptAudioFile(
            input: File('${directory.path}/missing'),
            output: output,
            encodedParameters: encoded,
          ),
          throwsA(isA<FileSystemException>()),
        );
        final handle = input.openSync(mode: FileMode.write);
        handle.truncateSync(maxAudioSampleFileSize + 1);
        handle.closeSync();
        await expectLater(
          decryptAudioFile(
            input: input,
            output: output,
            encodedParameters: encoded,
          ),
          throwsFormatException,
        );
        expect(input.lengthSync(), maxAudioSampleFileSize + 1);
        expect(output.readAsStringSync(), 'old');
        expect(directory.listSync().whereType<Directory>(), isEmpty);
      },
    );
    test(
      'publish failure removes temporary data and leaves input untouched',
      () async {
        final input = File('${directory.path}/input')
          ..writeAsStringSync('ciphertext');
        final target = Directory('${directory.path}/target')..createSync();
        await expectLater(
          decryptAudioFile(
            input: input,
            output: File(target.path),
            encodedParameters: vectors.first['parameters'] as String,
          ),
          throwsA(isA<FileSystemException>()),
        );
        expect(input.readAsStringSync(), 'ciphertext');
        expect(target.existsSync(), isTrue);
        expect(directory.listSync().length, 2);
      },
    );
  });
}
