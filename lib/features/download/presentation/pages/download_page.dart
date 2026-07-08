import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/utils/platform_utils.dart';
import '../../../../shared/widgets/adaptive_action_menu.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../domain/entities/download_state.dart';
import '../../domain/entities/download_task.dart';
import '../providers/download_providers.dart';

class DownloadPage extends ConsumerWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadControllerProvider);
    final localeCode = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(AppI18n.tByLocaleCode(localeCode, 'download.title')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: _DownloadTaskList(
            state: downloadState,
            onPause: ref.read(downloadControllerProvider.notifier).pause,
            onResume: ref.read(downloadControllerProvider.notifier).resume,
            onRedownload: ref
                .read(downloadControllerProvider.notifier)
                .redownload,
            onOpenLocation: ref
                .read(downloadControllerProvider.notifier)
                .openContainingFolder,
            onExportFiles: (taskId, sharePositionOrigin) => ref
                .read(downloadControllerProvider.notifier)
                .exportFiles(taskId, sharePositionOrigin: sharePositionOrigin),
            onRetry: ref.read(downloadControllerProvider.notifier).retry,
            onRemoveTask: ref
                .read(downloadControllerProvider.notifier)
                .removeTask,
            onRemoveTaskAndFile: ref
                .read(downloadControllerProvider.notifier)
                .removeTaskAndFile,
            onClearCompleted: ref
                .read(downloadControllerProvider.notifier)
                .clearCompleted,
          ),
        ),
      ),
    );
  }
}

class _DownloadTaskList extends StatelessWidget {
  const _DownloadTaskList({
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onRedownload,
    required this.onOpenLocation,
    required this.onExportFiles,
    required this.onRetry,
    required this.onRemoveTask,
    required this.onRemoveTaskAndFile,
    required this.onClearCompleted,
  });

  final DownloadState state;
  final ValueChanged<String> onPause;
  final ValueChanged<String> onResume;
  final ValueChanged<String> onRedownload;
  final ValueChanged<String> onOpenLocation;
  final Future<void> Function(String taskId, Rect? sharePositionOrigin)
  onExportFiles;
  final ValueChanged<String> onRetry;
  final ValueChanged<String> onRemoveTask;
  final ValueChanged<String> onRemoveTaskAndFile;
  final VoidCallback onClearCompleted;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    if (state.tasks.isEmpty) {
      return Center(
        child: Text(AppI18n.tByLocaleCode(localeCode, 'download.empty')),
      );
    }
    final tasks = List<DownloadTask>.from(state.tasks)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.separated(
            itemCount: tasks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _DownloadTaskRow(
                task: task,
                onPause: () => onPause(task.id),
                onResume: () => onResume(task.id),
                onRedownload: () => onRedownload(task.id),
                onOpenLocation: () => onOpenLocation(task.id),
                onExportFiles: (sharePositionOrigin) =>
                    onExportFiles(task.id, sharePositionOrigin),
                onRetry: () => onRetry(task.id),
                onRemoveTask: () => onRemoveTask(task.id),
                onRemoveTaskAndFile: () => onRemoveTaskAndFile(task.id),
              );
            },
          ),
        ),
        if (state.completedTasks.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onClearCompleted,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text(
                AppI18n.tByLocaleCode(
                  localeCode,
                  'download.action.clear_completed',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DownloadTaskRow extends StatelessWidget {
  const _DownloadTaskRow({
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onRedownload,
    required this.onOpenLocation,
    required this.onExportFiles,
    required this.onRetry,
    required this.onRemoveTask,
    required this.onRemoveTaskAndFile,
  });

  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRedownload;
  final VoidCallback onOpenLocation;
  final Future<void> Function(Rect? sharePositionOrigin) onExportFiles;
  final VoidCallback onRetry;
  final VoidCallback onRemoveTask;
  final VoidCallback onRemoveTaskAndFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  _displayFileName(task),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Align(
                  alignment: Alignment.topRight,
                  child: _MoreButton(
                    task: task,
                    onPause: onPause,
                    onResume: onResume,
                    onRedownload: onRedownload,
                    onOpenLocation: onOpenLocation,
                    onExportFiles: onExportFiles,
                    onRetry: onRetry,
                    onRemoveTask: onRemoveTask,
                    onRemoveTaskAndFile: onRemoveTaskAndFile,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _sizeLabel(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                task.effectiveFileExtension.trim().toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _statusLabel(context),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: _statusColor(colorScheme),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _displayFileName(DownloadTask task) {
    final filePath = (task.filePath ?? '').trim();
    if (filePath.isNotEmpty) {
      final normalized = filePath.replaceAll('\\', '/');
      final index = normalized.lastIndexOf('/');
      if (index >= 0 && index < normalized.length - 1) {
        return normalized.substring(index + 1);
      }
      return normalized;
    }
    final title = task.title.trim();
    final artist = (task.artist ?? '').trim();
    final extension = task.effectiveFileExtension.trim().toLowerCase();
    if (artist.isEmpty) {
      return '$title.$extension';
    }
    return '$title - $artist.$extension';
  }

  String _sizeLabel(BuildContext context) {
    final downloaded = task.downloadedBytes;
    final total = task.totalBytes;
    if (downloaded != null && total != null && total > 0) {
      return '${_formatBytes(downloaded)} / ${_formatBytes(total)}';
    }
    if (downloaded != null && downloaded > 0) {
      return _formatBytes(downloaded);
    }
    if (total != null && total > 0) {
      return _formatBytes(total);
    }
    return _statusLabel(context);
  }

  String _statusLabel(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    switch (task.status) {
      case DownloadTaskStatus.queued:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.queued');
      case DownloadTaskStatus.preparing:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.preparing');
      case DownloadTaskStatus.downloading:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.downloading');
      case DownloadTaskStatus.tagging:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.tagging');
      case DownloadTaskStatus.completed:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.completed');
      case DownloadTaskStatus.paused:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.paused');
      case DownloadTaskStatus.failed:
        return AppI18n.tByLocaleCode(localeCode, 'download.status.failed');
    }
  }

  Color _statusColor(ColorScheme colorScheme) {
    switch (task.status) {
      case DownloadTaskStatus.downloading:
        return const Color(0xFFCF8A17);
      case DownloadTaskStatus.tagging:
        return const Color(0xFF278BCB);
      case DownloadTaskStatus.failed:
        return colorScheme.error;
      case DownloadTaskStatus.completed:
        return const Color(0xFF2F9A5A);
      case DownloadTaskStatus.queued:
      case DownloadTaskStatus.paused:
        return colorScheme.onSurfaceVariant;
      case DownloadTaskStatus.preparing:
        return colorScheme.primary;
    }
  }

  String _formatBytes(int bytes) {
    const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index += 1;
    }
    final fractionDigits = value >= 100 || index == 0 ? 0 : 1;
    return '${value.toStringAsFixed(fractionDigits)} ${units[index]}';
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onRedownload,
    required this.onOpenLocation,
    required this.onExportFiles,
    required this.onRetry,
    required this.onRemoveTask,
    required this.onRemoveTaskAndFile,
  });

  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRedownload;
  final VoidCallback onOpenLocation;
  final Future<void> Function(Rect? sharePositionOrigin) onExportFiles;
  final VoidCallback onRetry;
  final VoidCallback onRemoveTask;
  final VoidCallback onRemoveTaskAndFile;

  String get _menuButtonKey => 'download_more_button_${task.id}';
  String get _pauseItemKey => 'download_more_pause_${task.id}';
  String get _resumeItemKey => 'download_more_resume_${task.id}';
  String get _redownloadItemKey => 'download_more_redownload_${task.id}';
  String get _openLocationItemKey => 'download_more_open_location_${task.id}';
  String get _exportFilesItemKey => 'download_more_export_files_${task.id}';
  String get _retryItemKey => 'download_more_retry_${task.id}';
  String get _removeTaskItemKey => 'download_more_remove_task_${task.id}';
  String get _removeTaskAndFileItemKey =>
      'download_more_remove_task_and_file_${task.id}';

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final platform = Theme.of(context).platform;
    if (shouldUseDesktopMenu(context)) {
      return AdaptiveActionMenu<String>(
        menuKey: Key(_menuButtonKey),
        tooltip: AppI18n.tByLocaleCode(localeCode, 'common.more'),
        icon: const Icon(Icons.more_horiz_rounded, size: 18),
        items: _buildActions(localeCode, platform),
        onSelected: (action) {
          _handleAction(context, action);
        },
      );
    }
    return IconButton(
      key: Key(_menuButtonKey),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      tooltip: AppI18n.tByLocaleCode(localeCode, 'common.more'),
      icon: const Icon(Icons.more_horiz_rounded, size: 18),
      onPressed: () => _showMobileMenu(context, localeCode, platform),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final sharePositionOrigin = _resolveSharePositionOrigin(context);
    switch (action) {
      case 'pause':
        onPause();
      case 'resume':
        onResume();
      case 'redownload':
        onRedownload();
      case 'open_location':
        onOpenLocation();
      case 'export_files':
        await onExportFiles(sharePositionOrigin);
      case 'retry':
        onRetry();
      case 'remove_task':
        onRemoveTask();
      case 'remove_task_and_file':
        onRemoveTaskAndFile();
    }
  }

  Future<void> _showMobileMenu(
    BuildContext context,
    String localeCode,
    TargetPlatform platform,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.60;
        final items = _buildActions(localeCode, platform);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: <Widget>[
                for (final item in items)
                  ListTile(
                    key: item.key,
                    leading: item.icon == null ? null : Icon(item.icon),
                    enabled: item.enabled,
                    title: Text(item.label),
                    onTap: item.enabled
                        ? () => Navigator.of(sheetContext).pop(item.value)
                        : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!context.mounted) {
      return;
    }
    if (selected != null) {
      await _handleAction(context, selected);
    }
  }

  Rect _resolveSharePositionOrigin(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  List<AdaptiveActionMenuItem<String>> _buildActions(
    String localeCode,
    TargetPlatform platform,
  ) {
    final items = <AdaptiveActionMenuItem<String>>[];
    if (task.status == DownloadTaskStatus.preparing ||
        task.status == DownloadTaskStatus.downloading ||
        task.status == DownloadTaskStatus.tagging) {
      items.add(
        AdaptiveActionMenuItem<String>(
          key: Key(_pauseItemKey),
          value: 'pause',
          label: AppI18n.tByLocaleCode(localeCode, 'download.action.pause'),
          icon: Icons.pause_rounded,
        ),
      );
    }
    if (task.status == DownloadTaskStatus.paused) {
      items.add(
        AdaptiveActionMenuItem<String>(
          key: Key(_resumeItemKey),
          value: 'resume',
          label: AppI18n.tByLocaleCode(localeCode, 'download.action.resume'),
          icon: Icons.play_arrow_rounded,
        ),
      );
    }
    if (task.status == DownloadTaskStatus.failed) {
      items.add(
        AdaptiveActionMenuItem<String>(
          key: Key(_retryItemKey),
          value: 'retry',
          label: AppI18n.tByLocaleCode(localeCode, 'download.action.retry'),
          icon: Icons.refresh_rounded,
        ),
      );
    }
    if (task.status == DownloadTaskStatus.completed) {
      items.add(
        AdaptiveActionMenuItem<String>(
          key: Key(_redownloadItemKey),
          value: 'redownload',
          label: AppI18n.tByLocaleCode(
            localeCode,
            'download.action.redownload',
          ),
          icon: Icons.download_for_offline_rounded,
        ),
      );
      if ((task.filePath ?? '').trim().isNotEmpty) {
        items.add(
          AdaptiveActionMenuItem<String>(
            key: Key(_openLocationItemKey),
            value: 'open_location',
            label:
                platform == TargetPlatform.android ||
                    platform == TargetPlatform.iOS
                ? (localeCode == 'zh' ? '打开文件' : 'Open File')
                : AppI18n.tByLocaleCode(
                    localeCode,
                    'download.action.open_location',
                  ),
            icon: Icons.folder_open_rounded,
          ),
        );
        if (platform == TargetPlatform.iOS ||
            platform == TargetPlatform.android) {
          items.add(
            AdaptiveActionMenuItem<String>(
              key: Key(_exportFilesItemKey),
              value: 'export_files',
              label: localeCode == 'zh' ? '导出文件' : 'Export File',
              icon: Icons.ios_share_rounded,
            ),
          );
        }
      }
    }
    items.add(
      AdaptiveActionMenuItem<String>(
        key: Key(_removeTaskItemKey),
        value: 'remove_task',
        label: AppI18n.tByLocaleCode(localeCode, 'download.action.remove_task'),
        icon: Icons.remove_circle_outline_rounded,
        destructive: true,
        startsNewSection: items.isNotEmpty,
      ),
    );
    items.add(
      AdaptiveActionMenuItem<String>(
        key: Key(_removeTaskAndFileItemKey),
        value: 'remove_task_and_file',
        label: AppI18n.tByLocaleCode(
          localeCode,
          'download.action.remove_task_and_file',
        ),
        icon: Icons.delete_outline_rounded,
        destructive: true,
      ),
    );
    return items;
  }
}
