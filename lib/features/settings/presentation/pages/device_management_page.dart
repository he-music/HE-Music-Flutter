import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../data/device_api_client.dart';
import '../controllers/device_management_controller.dart';

class DeviceManagementPage extends ConsumerStatefulWidget {
  const DeviceManagementPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<DeviceManagementPage> createState() =>
      _DeviceManagementPageState();
}

class _DeviceManagementPageState extends ConsumerState<DeviceManagementPage> {
  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final state = ref.watch(deviceManagementControllerProvider);

    final content = _buildContent(context, config, state);

    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(AppI18n.t(config, 'settings.device_management.title')),
      ),
      body: content,
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppConfigState config,
    DeviceManagementState state,
  ) {
    if (state.isLoading && state.devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref
                  .read(deviceManagementControllerProvider.notifier)
                  .loadDevices(),
              child: Text(AppI18n.t(config, 'common.retry')),
            ),
          ],
        ),
      );
    }

    if (state.devices.isEmpty) {
      return Center(
        child: Text(
          AppI18n.t(config, 'settings.device_management.empty'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(deviceManagementControllerProvider.notifier)
          .loadDevices(),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 设备数量标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              AppI18n.format(
                config,
                'settings.device_management.count',
                {'count': '${state.deviceCount}'},
              ),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // 设备列表
          ...state.devices.map(
            (device) => _DeviceCard(
              device: device,
              config: config,
              onDelete: () => _confirmDelete(context, config, device),
            ),
          ),
          // 批量删除按钮
          if (state.canBatchDelete) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: state.isLoading
                    ? null
                    : () => _confirmBatchDelete(context, config),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(
                  AppI18n.t(
                    config,
                    'settings.device_management.batch_delete',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppConfigState config,
    DeviceData device,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppI18n.t(config, 'settings.device_management.delete')),
        content: Text(
          AppI18n.t(config, 'settings.device_management.delete_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppI18n.t(config, 'common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppI18n.t(config, 'common.confirm')),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(deviceManagementControllerProvider.notifier)
          .deleteDevice(device.deviceId);
    }
  }

  Future<void> _confirmBatchDelete(
    BuildContext context,
    AppConfigState config,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppI18n.t(config, 'settings.device_management.batch_delete'),
        ),
        content: Text(
          AppI18n.t(
            config,
            'settings.device_management.batch_delete_confirm',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppI18n.t(config, 'common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppI18n.t(config, 'common.confirm')),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final count = await ref
          .read(deviceManagementControllerProvider.notifier)
          .batchDeleteDevices();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppI18n.format(
                config,
                'settings.device_management.batch_delete_done',
                {'count': '$count'},
              ),
            ),
          ),
        );
      }
    }
  }
}

/// 单个设备卡片
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.config,
    required this.onDelete,
  });

  final DeviceData device;
  final AppConfigState config;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCurrent = device.isCurrentDevice;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isCurrent
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 平台图标
            Icon(
              _platformIcon(device.platform),
              size: 32,
              color: isCurrent
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            // 设备信息
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 显示名
                  Text(
                    device.displayName.isNotEmpty
                        ? device.displayName
                        : device.deviceName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: isCurrent ? FontWeight.w600 : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 位置 + 时间
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ) ??
                        const TextStyle(),
                    child: Row(
                      children: [
                        if (device.location.isNotEmpty) ...[
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(device.location),
                          const SizedBox(width: 12),
                        ],
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(_formatLastActive(config, device.lastActiveAt)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 操作按钮
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  AppI18n.t(
                    config,
                    'settings.device_management.current_device',
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimary,
                  ),
                ),
              )
            else
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: colorScheme.error,
                tooltip: AppI18n.t(
                  config,
                  'settings.device_management.delete',
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'macos':
        return Icons.laptop_mac;
      case 'windows':
        return Icons.laptop_windows;
      case 'linux':
        return Icons.computer;
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      default:
        return Icons.devices;
    }
  }

  String _formatLastActive(AppConfigState config, int timestamp) {
    if (timestamp <= 0) return '';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - timestamp;
    if (diff < 60) {
      return AppI18n.t(config, 'settings.device_management.just_now');
    }
    if (diff < 3600) {
      final minutes = diff ~/ 60;
      return AppI18n.format(
        config,
        'settings.device_management.minutes_ago',
        {'count': '$minutes'},
      );
    }
    if (diff < 86400) {
      final hours = diff ~/ 3600;
      return AppI18n.format(
        config,
        'settings.device_management.hours_ago',
        {'count': '$hours'},
      );
    }
    final days = diff ~/ 86400;
    return AppI18n.format(
      config,
      'settings.device_management.days_ago',
      {'count': '$days'},
    );
  }
}
