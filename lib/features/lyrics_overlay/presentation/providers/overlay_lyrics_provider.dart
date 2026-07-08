import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../application/overlay_lyrics_service.dart';
import '../../domain/services/overlay_channel_service.dart';

final overlayLyricsServiceProvider = Provider<OverlayChannelService>((ref) {
  return OverlayLyricsService();
});

/// 监听 App 生命周期，当主进程恢复前台时检测 overlay 是否仍在活跃。
/// 解决 overlay 独立进程关闭后 Riverpod 状态不同步的问题：
/// overlay 进程关闭时直接写 SharedPreferences，但主进程的
/// [appConfigProvider] 不知道这个变化，导致设置页面显示过时状态。
final overlayLyricsBindingProvider = Provider<void>((ref) {
  final service = ref.read(overlayLyricsServiceProvider);

  Future<void> syncOverlayState() async {
    final overlayActive = await service.isActive();
    if (!overlayActive) {
      final config = ref.read(appConfigProvider);
      if (config.enableDesktopLyric) {
        ref.read(appConfigProvider.notifier).setEnableDesktopLyric(false);
      }
      if (config.enableDesktopLyricLock) {
        ref.read(appConfigProvider.notifier).setEnableDesktopLyricLock(false);
      }
    }
  }

  // App 从后台恢复时检查 overlay 状态
  final observer = _OverlayLifecycleObserver(onResume: syncOverlayState);
  WidgetsBinding.instance.addObserver(observer);

  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
  });
});

/// 仅监听 resume 事件的轻量生命周期观察者。
class _OverlayLifecycleObserver extends WidgetsBindingObserver {
  _OverlayLifecycleObserver({required this.onResume});

  final Future<void> Function() onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}
