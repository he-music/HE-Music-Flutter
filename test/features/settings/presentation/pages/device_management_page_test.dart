import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
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

  testWidgets('device list pull to refresh indicator has no elevation', (
    tester,
  ) async {
    await _pumpPage(tester, timestamp: 0);
    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    expect(indicator.elevation, 0);
  });

  for (final style in AppUiStyle.values) {
    for (final empty in [false, true]) {
      testWidgets('$style device ${empty ? "empty" : "list"} pull loads once', (
        tester,
      ) async {
        final controller = await _pumpPage(
          tester,
          timestamp: 0,
          style: style,
          empty: empty,
        );
        await tester.timedDrag(
          find.byType(CustomScrollView),
          const Offset(0, 500),
          const Duration(seconds: 1),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(controller.refreshCalls, 1);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
        await tester.pump(const Duration(seconds: 1));
        expect(controller.refreshCalls, 1);
        controller.refresh.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'Cupertino device delete dialog cancels and returns confirmation',
    (tester) async {
      final controller = await _pumpPage(
        tester,
        timestamp: 0,
        style: AppUiStyle.cupertino,
        currentDevice: false,
      );
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(CupertinoAlertDialog))),
        isA<CupertinoDialogRoute<bool>>(),
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(controller.deleteCalls, 0);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(controller.deleteCalls, 1);
    },
  );
}

Future<_TestDeviceManagementController> _pumpPage(
  WidgetTester tester, {
  required int timestamp,
  String localeCode = 'zh',
  String location = '北京',
  AppUiStyle style = AppUiStyle.material,
  bool empty = false,
  bool currentDevice = true,
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
    isCurrentDevice: currentDevice,
  );
  final controller = _TestDeviceManagementController(empty ? null : device);
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(localeCode),
      ),
      deviceManagementControllerProvider.overrideWith(() => controller),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) =>
            AppUiStyleScope(style: style, child: child!),
        home: const DeviceManagementPage(),
      ),
    ),
  );
  await tester.pump();
  return controller;
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
  final DeviceData? device;
  final refresh = Completer<void>();
  int refreshCalls = 0;
  int deleteCalls = 0;

  @override
  DeviceManagementState build() {
    return DeviceManagementState(
      devices: <DeviceData>[?device],
      currentDeviceId: device?.deviceId ?? '',
    );
  }

  @override
  Future<void> loadDevices() {
    refreshCalls++;
    return refresh.future;
  }

  @override
  Future<bool> deleteDevice(String deviceId) async {
    deleteCalls++;
    return true;
  }
}
