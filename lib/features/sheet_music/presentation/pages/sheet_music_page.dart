import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_error_message.dart';
import '../widgets/sheet_music_download_button.dart';
import '../widgets/sheet_music_reader.dart';
import '../widgets/sheet_music_list.dart';
import '../widgets/sheet_music_metadata.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../widgets/sheet_music_loading.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/entities/sheet_music_info.dart';
import '../../domain/entities/sheet_music_not_implemented_exception.dart';
import '../providers/sheet_music_providers.dart';

class SheetMusicListPage extends ConsumerWidget {
  const SheetMusicListPage({
    required this.platform,
    required this.songId,
    this.title = '',
    super.key,
  });

  final String platform;
  final String songId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    final request = (platform: platform, songId: songId);
    final provider = sheetMusicListProvider(request);
    final state = ref.watch(provider);
    final pageTitle = AppI18n.tByLocaleCode(locale, 'sheet_music.title');
    return _SheetMusicShell(
      title: title.isEmpty ? pageTitle : '$title · $pageTitle',
      child: state.when(
        skipLoadingOnRefresh: false,
        loading: () => SheetMusicListSkeleton(
          label: AppI18n.tByLocaleCode(locale, 'sheet_music.loading'),
        ),
        error: (error, _) => _SheetMusicError(
          error: error,
          locale: locale,
          onRetry: () {
            if (ref.read(onlinePlatformsProvider).hasError) {
              ref.invalidate(onlinePlatformsProvider);
            }
            ref.invalidate(provider);
          },
        ),
        data: (sheets) {
          if (sheets.isEmpty) {
            return _SheetMusicStatus(
              message: AppI18n.tByLocaleCode(locale, 'sheet_music.empty'),
            );
          }
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SheetMusicListSliver(
                  sheets: sheets,
                  platform: platform,
                  songId: songId,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SheetMusicDetailPage extends ConsumerWidget {
  const SheetMusicDetailPage({
    required this.platform,
    required this.songId,
    required this.id,
    this.title = '',
    super.key,
  });

  final String platform;
  final String songId;
  final String id;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    final request = (platform: platform, songId: songId, id: id);
    final provider = sheetMusicDetailProvider(request);
    final state = ref.watch(provider);
    final sheet = state.asData?.value;
    return _SheetMusicShell(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      subtitle: sheet == null ? null : sheetMusicTags(sheet),
      title: sheet == null
          ? (title.isEmpty
                ? AppI18n.tByLocaleCode(locale, 'sheet_music.title')
                : title)
          : sheetMusicTitle(sheet, locale),
      child: state.when(
        skipLoadingOnRefresh: false,
        loading: () => SheetMusicDetailSkeleton(
          label: AppI18n.tByLocaleCode(locale, 'sheet_music.loading'),
        ),
        error: (error, _) => _SheetMusicError(
          error: error,
          locale: locale,
          onRetry: () {
            if (ref.read(onlinePlatformsProvider).hasError) {
              ref.invalidate(onlinePlatformsProvider);
            }
            ref.invalidate(provider);
          },
        ),
        data: (sheet) => _SheetMusicDetailContent(
          key: ValueKey(request),
          request: request,
          sheet: sheet,
          locale: locale,
        ),
      ),
    );
  }
}

class _SheetMusicDetailContent extends StatelessWidget {
  const _SheetMusicDetailContent({
    required this.request,
    required this.sheet,
    required this.locale,
    super.key,
  });

  final SheetMusicDetailRequest request;
  final SheetMusicInfo sheet;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final download = SheetMusicDownloadButton(
      request: request,
      sheet: sheet,
      locale: locale,
      compact: true,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetMusicMetadata(sheet: sheet, locale: locale, showDetail: true),
        SheetMusicDownloadStatus(request: request, locale: locale),
        Expanded(
          child: sheet.pageUrls.isEmpty
              ? _SheetMusicStatus(
                  message: AppI18n.tByLocaleCode(
                    locale,
                    'sheet_music.resources_unavailable',
                  ),
                )
              : ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: SheetMusicReader(
                    pageUrls: sheet.pageUrls,
                    title: sheetMusicTitle(sheet, locale),
                    locale: locale,
                    trailingAction: download,
                    downloadStatus: SheetMusicDownloadStatus(
                      request: request,
                      locale: locale,
                    ),
                    currentPageActionBuilder: (index) =>
                        SheetMusicDownloadButton(
                          request: request,
                          sheet: sheet,
                          locale: locale,
                          pageIndex: index,
                        ),
                  ),
                ),
        ),
        if (sheet.pageUrls.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
            child: Align(alignment: Alignment.centerRight, child: download),
          ),
      ],
    );
  }
}

class _SheetMusicError extends StatelessWidget {
  const _SheetMusicError({
    required this.error,
    required this.locale,
    required this.onRetry,
  });

  final Object error;
  final String locale;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error is AppException
        ? (error as AppException).failure
        : null;
    final key = error is SheetMusicNotImplementedException
        ? 'sheet_music.not_open'
        : failure is UnsupportedFailure
        ? 'sheet_music.unsupported'
        : failure is ValidationFailure
        ? 'sheet_music.invalid_request'
        : null;
    final message = key != null
        ? AppI18n.tByLocaleCode(locale, key)
        : NetworkErrorMessage.resolve(error, localeCode: locale) ??
              AppI18n.tByLocaleCode(locale, 'error.network.request_failed');
    return _SheetMusicStatus(
      message: message,
      onRetry: onRetry,
      locale: locale,
    );
  }
}

class _SheetMusicStatus extends StatelessWidget {
  const _SheetMusicStatus({
    required this.message,
    this.onRetry,
    this.locale = 'zh',
  });

  final String message;
  final VoidCallback? onRetry;
  final String locale;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(AppI18n.tByLocaleCode(locale, 'common.retry')),
            ),
          ],
        ],
      ),
    ),
  );
}

class _SheetMusicShell extends StatelessWidget {
  const _SheetMusicShell({
    required this.title,
    required this.child,
    this.subtitle,
    this.backgroundColor,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final page = DetailPageShell(
      child: Column(
        children: [
          AppBar(
            backgroundColor: backgroundColor,
            surfaceTintColor: Colors.transparent,
            centerTitle: false,
            leadingWidth: backgroundColor == null ? null : 48,
            titleSpacing: backgroundColor == null ? null : 0,
            leading: const AppBackButton(iconSize: 22),
            title: backgroundColor == null
                ? Text(title)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (subtitle?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w400,
                              ),
                        ),
                      ],
                    ],
                  ),
            scrolledUnderElevation: 0,
          ),
          // The outer player shell includes floating chrome in bottom padding.
          Expanded(child: SafeArea(top: false, child: child)),
        ],
      ),
    );
    return backgroundColor == null
        ? page
        : Material(color: backgroundColor, child: page);
  }
}
