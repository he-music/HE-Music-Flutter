import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/i18n/app_i18n.dart';

/// The existing song-count label doubles as a compact load-all entry point.
/// Loading is owned by the page/controller, so collapsing a header cannot stop it.
class SongListCount extends StatelessWidget {
  const SongListCount({
    required this.loadedCount,
    required this.hasMore,
    required this.onLoadAll,
    this.totalCount,
    this.loading = false,
    this.error,
    super.key,
  });

  final int loadedCount;
  final int? totalCount;
  final bool hasMore;
  final bool loading;
  final String? error;
  final Future<void> Function() onLoadAll;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final knownTotal =
        totalCount != null && totalCount! > 0 && totalCount! >= loadedCount;
    final count = hasMore && knownTotal
        ? '$loadedCount/$totalCount'
        : '$loadedCount';
    final label = AppI18n.formatByLocaleCode(
      locale,
      'detail.song_count.compact',
      {'count': count},
    );
    final description = AppI18n.formatByLocaleCode(
      locale,
      knownTotal && hasMore
          ? 'detail.song_count.loaded_total'
          : 'detail.song_count.loaded',
      {'loaded': '$loadedCount', 'total': '$totalCount'},
    );
    final action = loading
        ? AppI18n.tByLocaleCode(locale, 'detail.song_count.loading')
        : error != null && hasMore
        ? AppI18n.tByLocaleCode(locale, 'detail.song_count.retry')
        : hasMore
        ? AppI18n.tByLocaleCode(locale, 'detail.song_count.load_all')
        : '';
    final hint = action.isEmpty
        ? label
        : '$description${locale == 'zh' ? '，' : '. '}$action';
    final color =
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    final canTap = hasMore && !loading;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (loading || hasMore) ...[
          const SizedBox(width: 4),
          if (loading)
            SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color,
                value: MediaQuery.disableAnimationsOf(context) ? 0.75 : null,
              ),
            )
          else
            Icon(
              error != null ? Icons.refresh_rounded : Icons.expand_more_rounded,
              size: 14,
              color: error != null
                  ? Theme.of(context).colorScheme.error
                  : color,
            ),
        ],
      ],
    );
    return Tooltip(
      message: hint,
      excludeFromSemantics: true,
      child: Semantics(
        label: hint,
        button: hasMore,
        enabled: hasMore ? !loading : null,
        liveRegion: loading,
        onTap: canTap ? () => unawaited(onLoadAll()) : null,
        child: ExcludeSemantics(
          child: canTap
              ? InkWell(
                  onTap: () => unawaited(onLoadAll()),
                  borderRadius: BorderRadius.circular(4),
                  child: content,
                )
              : content,
        ),
      ),
    );
  }
}
