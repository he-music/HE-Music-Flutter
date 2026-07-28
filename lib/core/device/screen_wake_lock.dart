import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

abstract interface class ScreenWakeLockPort {
  Future<void> setEnabled(bool enabled);
}

class WakelockPlusScreenWakeLockPort implements ScreenWakeLockPort {
  const WakelockPlusScreenWakeLockPort();

  @override
  Future<void> setEnabled(bool enabled) {
    return WakelockPlus.toggle(enable: enabled);
  }
}

final screenWakeLockPortProvider = Provider<ScreenWakeLockPort>((ref) {
  return const WakelockPlusScreenWakeLockPort();
});
