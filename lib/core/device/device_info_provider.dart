import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _deviceIdKey = 'app_config.device_id';

class DeviceInfoData {
  const DeviceInfoData({
    required this.deviceId,
    required this.platform,
    required this.appType,
    required this.appVersion,
    required this.deviceName,
  });

  /// 格式: flutter_{platform}_{uuid}
  final String deviceId;
  final String platform;
  final String appType;
  final String appVersion;
  final String deviceName;

  /// 转为 API 请求用的 Map（对应 proto DeviceInfo）
  Map<String, dynamic> toApiMap() => <String, dynamic>{
    'device_id': deviceId,
    'platform': platform,
    'app_type': appType,
    'app_version': appVersion,
    'device_name': deviceName,
  };
}

/// 提供当前设备信息的 Riverpod Provider。
/// 内部会自动生成并持久化 device_id。
final deviceInfoProvider = FutureProvider<DeviceInfoData>((ref) async {
  final prefs = await SharedPreferences.getInstance();

  // 读取或生成 device_id
  var deviceId = prefs.getString(_deviceIdKey);
  if (deviceId == null || deviceId.isEmpty) {
    final uuid = const Uuid().v4();
    deviceId = 'flutter_${Platform.operatingSystem}_$uuid';
    await prefs.setString(_deviceIdKey, deviceId);
  }

  // 获取平台信息
  final platform = Platform.operatingSystem;

  // 获取应用版本
  final packageInfo = await PackageInfo.fromPlatform();
  final appVersion = packageInfo.version;

  // 获取设备名称
  final deviceInfo = DeviceInfoPlugin();
  final deviceName = await _resolveDeviceName(deviceInfo);

  return DeviceInfoData(
    deviceId: deviceId,
    platform: platform,
    appType: 'flutter',
    appVersion: appVersion,
    deviceName: deviceName,
  );
});

Future<String> _resolveDeviceName(DeviceInfoPlugin plugin) async {
  try {
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return '${info.manufacturer} ${info.model}';
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return info.name;
    }
    if (Platform.isMacOS) {
      final info = await plugin.macOsInfo;
      return info.computerName;
    }
    return Platform.operatingSystem;
  } catch (_) {
    return Platform.operatingSystem;
  }
}
