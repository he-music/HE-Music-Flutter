import 'package:flutter/material.dart';

import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../domain/entities/update_release.dart';

Future<void> showUpdateAvailableReleaseSheet({
  required BuildContext context,
  required AppConfigState config,
  required UpdateRelease release,
  required String? downloadUrl,
  required Future<void> Function(String rawUrl) onOpenUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final releaseNotes = release.releaseNotes.trim().isEmpty
          ? AppI18n.t(config, 'settings.about.release_notes.empty')
          : release.releaseNotes.trim();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppI18n.t(config, 'settings.about.available'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.new_releases_outlined),
                title: Text(release.version.normalized),
                subtitle: Text(_formatPublishedAt(release.publishedAt)),
                trailing: downloadUrl == null
                    ? null
                    : IconButton(
                        key: const ValueKey<String>(
                          'open-official-github-release',
                        ),
                        tooltip: AppI18n.t(
                          config,
                          'settings.about.view_release',
                        ),
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await onOpenUrl(release.htmlUrl);
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                AppI18n.t(config, 'settings.about.release_notes'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(child: Text(releaseNotes)),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(
                        AppI18n.t(
                          config,
                          downloadUrl == null
                              ? 'common.cancel'
                              : 'common.later',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await onOpenUrl(downloadUrl ?? release.htmlUrl);
                      },
                      child: Text(
                        AppI18n.t(
                          config,
                          downloadUrl == null
                              ? 'settings.about.open_release'
                              : 'settings.about.download_update',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _formatPublishedAt(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
