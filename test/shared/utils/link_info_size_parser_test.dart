import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/utils/link_info_size_parser.dart';

void main() {
  test('parses positive byte and binary unit LinkInfo sizes', () {
    expect(parseLinkInfoSizeBytes('1'), 1);
    expect(parseLinkInfoSizeBytes('12 KB'), 12 * 1024);
    expect(parseLinkInfoSizeBytes('3mb'), 3 * 1024 * 1024);
    expect(parseLinkInfoSizeBytes('2GB'), 2 * 1024 * 1024 * 1024);
  });

  test('rejects unknown, non-integral, non-positive and overflowing sizes', () {
    for (final value in <String>[
      '',
      '0',
      '-1',
      '1.5 MB',
      '1 KiB',
      '1 TB',
      '12 bytes',
      'unknown',
      '9223372036854775807GB',
    ]) {
      expect(parseLinkInfoSizeBytes(value), isNull, reason: value);
    }
  });
}
