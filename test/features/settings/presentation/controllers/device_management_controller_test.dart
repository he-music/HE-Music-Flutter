import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_ui_style.dart';
import 'package:he_music_flutter/app/theme/app_ui_theme.dart';
import 'package:he_music_flutter/features/settings/data/device_api_client.dart';
import 'package:he_music_flutter/features/settings/data/providers/device_providers.dart';
import 'package:he_music_flutter/features/settings/presentation/controllers/device_management_controller.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/device_management_page.dart';

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets('$style initial device load and pull share one request', (
      tester,
    ) async {
      final client = _PendingDeviceApiClient();
      final container = _container(client);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: AppUiStyleScope(
              style: style,
              child: const DeviceManagementPage(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(client.requests, hasLength(1));
      final controller = container.read(
        deviceManagementControllerProvider.notifier,
      );
      final first = controller.loadDevices();
      expect(controller.loadDevices(), same(first));
      await tester.timedDrag(
        find.byType(CustomScrollView),
        const Offset(0, 300),
        const Duration(seconds: 1),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(client.requests, hasLength(1));
      client.requests.single.complete(_result('initial'));
      await first;
      await tester.pumpAndSettle();
      expect(
        container
            .read(deviceManagementControllerProvider)
            .devices
            .single
            .deviceId,
        'initial',
      );
      final next = controller.loadDevices();
      expect(client.requests, hasLength(2));
      client.requests.last.complete(_result('updated'));
      await next;
      await tester.pumpAndSettle();
      expect(
        container
            .read(deviceManagementControllerProvider)
            .devices
            .single
            .deviceId,
        'updated',
      );
    });
  }

  for (final batch in [false, true]) {
    test(
      '${batch ? "batch" : "single"} deletion refreshes after older list request completes',
      () async {
        final client = _PendingDeviceApiClient();
        final container = _container(client);
        addTearDown(container.dispose);
        final controller = container.read(
          deviceManagementControllerProvider.notifier,
        );
        await Future<void>.delayed(Duration.zero);
        expect(client.requests, hasLength(1));
        final deletion = batch
            ? controller.batchDeleteDevices().then((count) {
                expect(count, 1);
              })
            : controller.deleteDevice('deleted');
        await Future<void>.delayed(Duration.zero);
        expect(client.deletions, 1);
        expect(client.requests, hasLength(1));
        client.requests.single.complete(_result('deleted'));
        await Future<void>.delayed(Duration.zero);
        expect(client.requests, hasLength(2));
        final joined = controller.loadDevices();
        client.requests.last.complete(
          const DeviceListResult(devices: [], currentDeviceId: ''),
        );
        await deletion;
        await joined;
        expect(
          container.read(deviceManagementControllerProvider).devices,
          isEmpty,
        );
        expect(client.requests, hasLength(2));
      },
    );
  }

  test('failed device load releases request for retry', () async {
    final client = _PendingDeviceApiClient();
    final container = _container(client);
    addTearDown(container.dispose);
    final controller = container.read(
      deviceManagementControllerProvider.notifier,
    );
    await Future<void>.delayed(Duration.zero);
    final pending = controller.loadDevices();
    client.requests.single.completeError(Exception('offline'));
    await pending;
    expect(
      container.read(deviceManagementControllerProvider).error,
      contains('offline'),
    );
    final retry = controller.loadDevices();
    expect(client.requests, hasLength(2));
    client.requests.last.complete(_result('retried'));
    await retry;
    expect(container.read(deviceManagementControllerProvider).error, isNull);
    expect(
      container
          .read(deviceManagementControllerProvider)
          .devices
          .single
          .deviceId,
      'retried',
    );
  });
}

ProviderContainer _container(_PendingDeviceApiClient client) =>
    ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_AuthenticatedConfig.new),
        deviceApiClientProvider.overrideWithValue(client),
      ],
    );

DeviceListResult _result(String id) => DeviceListResult(
  devices: [
    DeviceData(
      deviceId: id,
      displayName: id,
      platform: 'android',
      appType: 'mobile',
      appVersion: '1',
      deviceName: id,
      location: '',
      lastActiveAt: 0,
      isCurrentDevice: true,
    ),
  ],
  currentDeviceId: id,
);

class _AuthenticatedConfig extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(authToken: 'token');
}

class _PendingDeviceApiClient extends DeviceApiClient {
  _PendingDeviceApiClient() : super(Dio());
  final requests = <Completer<DeviceListResult>>[];
  int deletions = 0;

  @override
  Future<DeviceListResult> getUserDevices() {
    final request = Completer<DeviceListResult>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    deletions++;
  }

  @override
  Future<BatchDeleteResult> batchDeleteDevices() async {
    deletions++;
    return const BatchDeleteResult(deletedCount: 1);
  }
}
