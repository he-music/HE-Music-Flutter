import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_version.dart';

void main() {
  test('parse removes leading v and compares semantic versions', () {
    final current = UpdateVersion.parse('1.2.3');
    final latest = UpdateVersion.parse('v1.3.0');

    expect(current.compareTo(latest), lessThan(0));
    expect(latest.normalized, '1.3.0');
  });

  test('parse rejects invalid version text', () {
    expect(() => UpdateVersion.parse('main'), throwsFormatException);
  });
}
