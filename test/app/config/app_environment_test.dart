import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_environment.dart';

void main() {
  group('AppEnvironment.selectApiBaseUrl', () {
    test('should prefer non-empty compilation environment value', () {
      final value = AppEnvironment.selectApiBaseUrl(
        definedApiBaseUrl: ' https://api.example.com/ ',
        assetApiBaseUrl: 'https://example.com',
      );

      expect(value, 'https://api.example.com/');
    });

    test('should fallback to asset value when environment value is empty', () {
      final value = AppEnvironment.selectApiBaseUrl(
        definedApiBaseUrl: '  ',
        assetApiBaseUrl: ' https://example.com ',
      );

      expect(value, 'https://example.com');
    });
  });
}
