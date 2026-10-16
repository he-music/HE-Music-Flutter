import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../core/network/network_error_message.dart';
import '../../domain/entities/sheet_music_info.dart';
import '../../domain/repositories/sheet_music_download_repository.dart';
import '../providers/sheet_music_providers.dart';

class SheetMusicDownloadButton extends ConsumerWidget {
  const SheetMusicDownloadButton({
    required this.request,
    required this.sheet,
    required this.locale,
    this.pageIndex,
    this.compact = false,
    super.key,
  });

  final SheetMusicDetailRequest request;
  final SheetMusicInfo sheet;
  final String locale;
  final int? pageIndex;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sheetMusicDownloadProvider(request);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final retry = pageIndex == null && state.failedPages.isNotEmpty;
    final label = state.running
        ? AppI18n.formatByLocaleCode(locale, 'sheet_music.download_progress', {
            'current': '${state.processed}',
            'total': '${state.total}',
          })
        : AppI18n.tByLocaleCode(
            locale,
            retry
                ? 'sheet_music.retry_failed'
                : pageIndex != null
                ? 'sheet_music.save_current'
                : 'sheet_music.download_all',
          );
    return Tooltip(
      message: label,
      child: TextButton.icon(
        style: compact
            ? TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                textStyle: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 44),
              )
            : null,
        key: ValueKey(
          pageIndex == null ? 'sheet-download-all' : 'sheet-download-current',
        ),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        icon: Icon(
          retry ? Icons.refresh_rounded : Icons.download_rounded,
          size: compact ? 16 : 18,
        ),
        onPressed: state.running || sheet.pageUrls.isEmpty
            ? null
            : () async {
                final result = retry
                    ? await controller.retryFailed()
                    : await controller.download(sheet, pageIndex: pageIndex);
                if (result == null ||
                    !result.finished ||
                    result.error != null) {
                  return;
                }
                AppMessageService.showSuccess(
                  AppI18n.formatByLocaleCode(
                    locale,
                    result.directoryPath == null
                        ? 'sheet_music.saved_gallery'
                        : 'sheet_music.saved_directory',
                    {'count': '${result.savedCount}'},
                  ),
                );
              },
      ),
    );
  }
}

class SheetMusicDownloadStatus extends ConsumerWidget {
  const SheetMusicDownloadStatus({
    required this.request,
    required this.locale,
    super.key,
  });

  final SheetMusicDetailRequest request;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sheetMusicDownloadProvider(request));
    final error = state.error;
    if (state.running || error == null) {
      return const SizedBox.shrink();
    }
    final errorMessage = error is SheetMusicSaveException
        ? AppI18n.tByLocaleCode(locale, error.messageKey)
        : NetworkErrorMessage.resolve(error, localeCode: locale);
    final message = AppI18n.formatByLocaleCode(
      locale,
      'sheet_music.download_partial',
      {'saved': '${state.savedCount}', 'failed': '${state.failedPages.length}'},
    );
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Tooltip(
          message: errorMessage ?? state.directoryPath ?? message,
          child: Text(
            errorMessage == null ? message : '$message · $errorMessage',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
    );
  }
}
