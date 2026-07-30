import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum RealtimeSpectrumPermissionState { granted, denied, permanentlyDenied }

abstract interface class RealtimeSpectrumPermissionPort {
  Future<RealtimeSpectrumPermissionState> status();

  Future<RealtimeSpectrumPermissionState> request();

  Future<bool> openSettings();
}

class PermissionHandlerRealtimeSpectrumPermissionPort
    implements RealtimeSpectrumPermissionPort {
  const PermissionHandlerRealtimeSpectrumPermissionPort();

  @override
  Future<RealtimeSpectrumPermissionState> status() async {
    return _mapStatus(await Permission.microphone.status);
  }

  @override
  Future<RealtimeSpectrumPermissionState> request() async {
    return _mapStatus(await Permission.microphone.request());
  }

  @override
  Future<bool> openSettings() => openAppSettings();

  RealtimeSpectrumPermissionState _mapStatus(PermissionStatus status) {
    if (status.isGranted) {
      return RealtimeSpectrumPermissionState.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return RealtimeSpectrumPermissionState.permanentlyDenied;
    }
    return RealtimeSpectrumPermissionState.denied;
  }
}

final realtimeSpectrumPermissionPortProvider =
    Provider<RealtimeSpectrumPermissionPort>((ref) {
      return const PermissionHandlerRealtimeSpectrumPermissionPort();
    });
