import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';

void main() {
  group('buildLoginLocation', () {
    test('播放器触发登录时将回跳目标改为首页', () {
      final location = Uri.parse(buildLoginLocation(AppRoutes.player));

      expect(location.path, AppRoutes.login);
      expect(location.queryParameters['redirect'], AppRoutes.home);
    });

    test('普通页面触发登录时保留原回跳目标', () {
      final location = Uri.parse(buildLoginLocation(AppRoutes.settings));

      expect(location.path, AppRoutes.login);
      expect(location.queryParameters['redirect'], AppRoutes.settings);
    });
  });
}
