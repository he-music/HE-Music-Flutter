import 'package:dio/dio.dart';

/// 设备数据模型（对应 proto Device 消息）
class DeviceData {
  const DeviceData({
    required this.deviceId,
    required this.displayName,
    required this.platform,
    required this.appType,
    required this.appVersion,
    required this.deviceName,
    required this.location,
    required this.lastActiveAt,
    required this.isCurrentDevice,
  });

  final String deviceId;
  final String displayName;
  final String platform;
  final String appType;
  final String appVersion;
  final String deviceName;
  final String location;
  final int lastActiveAt;
  final bool isCurrentDevice;

  factory DeviceData.fromMap(Map<String, dynamic> map) {
    return DeviceData(
      deviceId: '${map['device_id'] ?? ''}'.trim(),
      displayName: '${map['display_name'] ?? ''}'.trim(),
      platform: '${map['platform'] ?? ''}'.trim(),
      appType: '${map['app_type'] ?? ''}'.trim(),
      appVersion: '${map['app_version'] ?? ''}'.trim(),
      deviceName: '${map['device_name'] ?? ''}'.trim(),
      location: '${map['location'] ?? ''}'.trim(),
      lastActiveAt: map['last_active_at'] is int
          ? map['last_active_at'] as int
          : 0,
      isCurrentDevice: map['is_current_device'] == true,
    );
  }
}

/// 设备列表结果
class DeviceListResult {
  const DeviceListResult({
    required this.devices,
    required this.currentDeviceId,
  });

  final List<DeviceData> devices;
  final String currentDeviceId;
}

/// 批量删除结果
class BatchDeleteResult {
  const BatchDeleteResult({required this.deletedCount});

  final int deletedCount;
}

/// 设备管理 API 客户端
class DeviceApiClient {
  DeviceApiClient(this._dio);

  final Dio _dio;

  /// 获取用户设备列表
  Future<DeviceListResult> getUserDevices() async {
    final response = await _dio.get('/v1/auth/devices');
    final data = _asMap(response.data);
    final list = data['devices'];
    final devices = <DeviceData>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          devices.add(
            DeviceData.fromMap(
              item.map((key, value) => MapEntry('$key', value)),
            ),
          );
        }
      }
    }
    return DeviceListResult(
      devices: devices,
      currentDeviceId: '${data['current_device_id'] ?? ''}'.trim(),
    );
  }

  /// 删除单个设备
  Future<void> deleteDevice(String deviceId) async {
    await _dio.delete('/v1/auth/devices/$deviceId');
  }

  /// 批量删除设备（排除当前设备）
  Future<BatchDeleteResult> batchDeleteDevices() async {
    final response = await _dio.delete('/v1/auth/devices/batch');
    final data = _asMap(response.data);
    return BatchDeleteResult(
      deletedCount: data['deleted_count'] is int
          ? data['deleted_count'] as int
          : 0,
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }
}
