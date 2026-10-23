import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../providers/online_providers.dart';

class OnlinePlatformStatusBanner extends ConsumerWidget {
  const OnlinePlatformStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(onlinePlatformSyncProvider);
    if (!sync.usingCache) return const SizedBox.shrink();
    final locale = ref.watch(
      appConfigProvider.select((value) => value.localeCode),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppI18n.tByLocaleCode(
                locale,
                sync.refreshFailed
                    ? 'platform.refresh_failed'
                    : 'platform.cached',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: sync.refreshing
                ? null
                : () => ref.read(onlinePlatformsProvider.notifier).refresh(),
            child: Text(AppI18n.tByLocaleCode(locale, 'common.retry')),
          ),
        ],
      ),
    );
  }
}
