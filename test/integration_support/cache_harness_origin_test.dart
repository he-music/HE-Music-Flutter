import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/cache_harness_origin.dart';

void main() {
  test(
    'generated fixture has complete PCM RIFF lengths and audible samples',
    () {
      final bytes = cacheHarnessWave(seconds: 1);
      final header = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(header.getUint32(4, Endian.little), bytes.length - 8);
      expect(header.getUint32(40, Endian.little), 44100 * 2);
      expect(header.getUint16(20, Endian.little), 1);
      expect(header.getUint16(34, Endian.little), 16);
      expect(bytes.skip(44).any((value) => value != 0), isTrue);
    },
  );

  test(
    'single range handles full, open, bounded, suffix and unsatisfiable requests',
    () {
      expect(cacheHarnessRange(null, 100), (start: 0, end: 99));
      expect(cacheHarnessRange('bytes=10-20', 100), (start: 10, end: 20));
      expect(cacheHarnessRange('bytes=10-', 100), (start: 10, end: 99));
      expect(cacheHarnessRange('bytes=90-999', 100), (start: 90, end: 99));
      expect(cacheHarnessRange('bytes=-10', 100), (start: 90, end: 99));
      expect(cacheHarnessRange('bytes=-999', 100), (start: 0, end: 99));
      for (final header in [
        'bytes=100-',
        'bytes=20-10',
        'bytes=-0',
        'bytes=-',
        'bytes=0-1,5-6',
        'invalid',
      ]) {
        expect(cacheHarnessRange(header, 100), isNull, reason: header);
      }
    },
  );
}
