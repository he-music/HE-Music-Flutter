import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/skin/app_skin_bottom_sheet.dart';
import '../../../../shared/constants/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../domain/entities/update_release.dart';
import '../../domain/services/update_download_resolver.dart';

Future<void> showUpdateAvailableReleaseSheet({
  required BuildContext context,
  required AppConfigState config,
  required UpdateRelease release,
  required UpdateDownloadTarget? downloadTarget,
  required Future<void> Function(String rawUrl) onOpenUrl,
}) {
  return showAppThemedBottomSheet<void>(
    fixedHeightFactor: LayoutTokens.contentSheetHeightFactor,
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final releaseNotes = release.releaseNotes.trim().isEmpty
          ? AppI18n.t(config, 'settings.about.release_notes.empty')
          : release.releaseNotes.trim();
      const compactButtonStyle = ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, 44)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scrollWholeSheet =
                  constraints.maxHeight < 480 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18.2;
              // 大字体或较矮的面板改为整体滚动，避免固定操作区挤出可用高度。
              final acceleratedUrl = downloadTarget?.acceleratedUrl;
              Future<void> openRegularDownload() async {
                Navigator.of(sheetContext).pop();
                await onOpenUrl(downloadTarget?.officialUrl ?? release.htmlUrl);
              }

              final regularLabel = Text(
                AppI18n.t(
                  config,
                  downloadTarget == null
                      ? 'settings.about.open_release'
                      : 'settings.about.regular_download',
                ),
                textAlign: TextAlign.center,
              );
              final notes = MarkdownBody(
                data: releaseNotes,
                onTapLink: (_, href, _) async {
                  final uri = href == null ? null : Uri.tryParse(href);
                  // Release 内容来自远端，仅允许系统浏览器处理绝对 Web 链接。
                  if (uri == null ||
                      !uri.hasAuthority ||
                      (uri.scheme != 'http' && uri.scheme != 'https')) {
                    return;
                  }
                  await onOpenUrl(uri.toString());
                },
                // 更新日志来自远端，图片仅显示替代文本，避免隐式加载外部资源。
                imageBuilder: (_, _, alt) => Text(alt ?? ''),
              );
              final content = Column(
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
                    trailing: downloadTarget == null
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
                  if (scrollWholeSheet)
                    notes
                  else
                    Flexible(child: SingleChildScrollView(child: notes)),
                  TextButton.icon(
                    style: compactButtonStyle,
                    onPressed: () => context.push(
                      Uri(
                        path: AppRoutes.releaseHistory,
                        queryParameters: {'latest': release.version.normalized},
                      ).toString(),
                    ),
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: Text(AppI18n.t(config, 'update.history.open')),
                  ),
                  const SizedBox(height: 8),
                  if (acceleratedUrl != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: compactButtonStyle,
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await onOpenUrl(acceleratedUrl);
                        },
                        icon: const Icon(Icons.bolt_rounded, size: 18),
                        label: Text(
                          AppI18n.t(
                            config,
                            'settings.about.accelerated_download',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          style: compactButtonStyle,
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: Text(
                            AppI18n.t(
                              config,
                              downloadTarget == null
                                  ? 'common.cancel'
                                  : 'common.later',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: acceleratedUrl != null
                            ? OutlinedButton(
                                style: compactButtonStyle,
                                onPressed: openRegularDownload,
                                child: regularLabel,
                              )
                            : FilledButton(
                                style: compactButtonStyle,
                                onPressed: openRegularDownload,
                                child: regularLabel,
                              ),
                      ),
                    ],
                  ),
                ],
              );
              return scrollWholeSheet
                  ? SingleChildScrollView(child: content)
                  : content;
            },
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
