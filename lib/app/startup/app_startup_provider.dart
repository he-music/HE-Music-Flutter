import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config_controller.dart';
import '../i18n/app_i18n.dart';

/// App 启动初始化：校验配置完整性，短暂展示启动页。
final appStartupProvider = FutureProvider<void>((ref) async {
  final apiBaseUrl = ref.read(appConfigProvider).apiBaseUrl.trim();
  if (apiBaseUrl.isEmpty) {
    final config = ref.read(appConfigProvider);
    throw StateError(AppI18n.t(config, 'startup.config_missing'));
  }
  // 保持启动页展示至少 1.5 秒，避免闪烁。
  await Future.delayed(const Duration(milliseconds: 1500));
});
