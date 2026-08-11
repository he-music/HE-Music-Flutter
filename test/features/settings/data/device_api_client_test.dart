import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/settings/data/device_api_client.dart';

void main() {
  group('DeviceData', () {
    test('parses protobuf int64 last active timestamp string', () {
      final device = DeviceData.fromMap(<String, dynamic>{
        'last_active_at': '1770000123',
      });

      expect(device.lastActiveAt, 1770000123);
    });

    test('keeps integer last active timestamp', () {
      final device = DeviceData.fromMap(<String, dynamic>{
        'last_active_at': 1770000123,
      });

      expect(device.lastActiveAt, 1770000123);
    });
  });
}
