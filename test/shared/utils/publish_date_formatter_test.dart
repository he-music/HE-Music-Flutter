import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/utils/publish_date_formatter.dart';

void main() {
  test('zero publish timestamps are treated as missing', () {
    expect(formatPublishDateOrEmpty('0'), isEmpty);
    expect(formatPublishDateOrEmpty(''), isEmpty);
  });

  test('publish timestamps support seconds, milliseconds, and ISO dates', () {
    expect(formatPublishDateOrEmpty('1704067200'), '2024-01-01');
    expect(formatPublishDateOrEmpty('1704067200000'), '2024-01-01');
    expect(formatPublishDateOrEmpty('2024-01-01T12:30:00Z'), '2024-01-01');
  });
}
