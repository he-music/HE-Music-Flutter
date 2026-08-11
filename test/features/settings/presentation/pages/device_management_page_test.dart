import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/settings/data/device_api_client.dart';
import 'package:he_music_flutter/features/settings/presentation/controllers/device_management_controller.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/device_management_page.dart';

void main() {
  testWidgets('device card shows localized last active time', (tester) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 300;

    await _pumpPage(tester, timestamp: timestamp);

    expect(find.text('最后活跃：5 分钟前'), findsOneWidget);
  });

  testWidgets('english device card does not overflow on narrow screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 7200;

    await _pumpPage(
      tester,
      timestamp: timestamp,
      localeCode: 'en',
      location: 'San Francisco, California',
    );

    expect(find.text('Last active: 2 hour(s) ago'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required int timestamp,
  String localeCode = 'zh',
  String location = '北京',
}) async {
  final device = DeviceData(
    deviceId: 'device-1',
    displayName: 'Test Device',
    platform: 'android',
    appType: 'mobile',
    appVersion: '1.0.0',
    deviceName: 'Android Phone',
    location: location,
    lastActiveAt: timestamp,
    isCurrentDevice: true,
  );
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(localeCode),
      ),
      deviceManagementControllerProvider.overrideWith(
        () => _TestDeviceManagementController(device),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DeviceManagementPage()),
    ),
  );
  await tester.pump();
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController(this.localeCode);

  final String localeCode;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      authToken: 'token',
      localeCode: localeCode,
    );
  }
}

class _TestDeviceManagementController extends DeviceManagementController {
  _TestDeviceManagementController(this.device);

  final DeviceData device;

  @override
  DeviceManagementState build() {
    return DeviceManagementState(
      devices: <DeviceData>[device],
      currentDeviceId: device.deviceId,
    );
  }
}
