import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../data/device_api_client.dart';
import '../../data/providers/device_providers.dart';

class DeviceManagementState {
  const DeviceManagementState({
    this.devices = const [],
    this.currentDeviceId = '',
    this.isLoading = false,
    this.error,
  });

  final List<DeviceData> devices;
  final String currentDeviceId;
  final bool isLoading;
  final String? error;

  int get deviceCount => devices.length;
  bool get canBatchDelete => devices.length > 1;

  DeviceManagementState copyWith({
    List<DeviceData>? devices,
    String? currentDeviceId,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DeviceManagementState(
      devices: devices ?? this.devices,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DeviceManagementController
    extends Notifier<DeviceManagementState> {
  @override
  DeviceManagementState build() {
    Future.microtask(loadDevices);
    return const DeviceManagementState();
  }

  Future<void> loadDevices() async {
    final token = ref.read(appConfigProvider).authToken;
    if (token == null || token.isEmpty) {
      state = const DeviceManagementState();
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final client = ref.read(deviceApiClientProvider);
      final result = await client.getUserDevices();
      state = state.copyWith(
        devices: result.devices,
        currentDeviceId: result.currentDeviceId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteDevice(String deviceId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final client = ref.read(deviceApiClientProvider);
      await client.deleteDevice(deviceId);
      await loadDevices();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<int> batchDeleteDevices() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final client = ref.read(deviceApiClientProvider);
      final result = await client.batchDeleteDevices();
      await loadDevices();
      return result.deletedCount;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final deviceManagementControllerProvider =
    NotifierProvider<DeviceManagementController, DeviceManagementState>(
  DeviceManagementController.new,
);
