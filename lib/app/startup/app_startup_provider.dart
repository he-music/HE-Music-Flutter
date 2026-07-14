import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config_controller.dart';
import '../i18n/app_i18n.dart';
import '../../features/online/presentation/providers/online_providers.dart';

/// App 启动初始化：等待配置水合并预加载全局平台列表。
final appStartupProvider = FutureProvider<void>((ref) async {
  await ref.read(appConfigProvider.notifier).waitUntilHydrated();
  final apiBaseUrl = ref.read(appConfigProvider).apiBaseUrl.trim();
  if (apiBaseUrl.isEmpty) {
    final config = ref.read(appConfigProvider);
    throw StateError(AppI18n.t(config, 'startup.config_missing'));
  }
  await ref.read(onlinePlatformsProvider.notifier).ensureLoaded();
}, retry: (_, _) => null);
