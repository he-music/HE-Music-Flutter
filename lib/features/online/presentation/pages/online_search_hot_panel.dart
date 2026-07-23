import 'package:flutter/material.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/skin/app_skin_icon.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../shared/widgets/plaza_loading_skeleton.dart';

class OnlineSearchHotPanel extends StatelessWidget {
  const OnlineSearchHotPanel({
    required this.localeCode,
    required this.historyKeywords,
    required this.hotKeywords,
    required this.loadingHistory,
    required this.loadingHot,
    required this.onTapKeyword,
    required this.onClearHistory,
    super.key,
  });

  final String localeCode;
  final List<String> historyKeywords;
  final List<String> hotKeywords;
  final bool loadingHistory;
  final bool loadingHot;
  final ValueChanged<String> onTapKeyword;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      children: <Widget>[
        // 没有搜索历史且不在加载中时，隐藏整个历史栏目
        if (loadingHistory) ...<Widget>[
          _SectionHeader(
            title: AppI18n.tByLocaleCode(localeCode, 'search.history.title'),
            trailing: IconButton(
              onPressed: onClearHistory,
              tooltip: AppI18n.tByLocaleCode(localeCode, 'common.clear'),
              icon: const AppSkinIcon(role: AppSkinIconRole.searchHistoryClear),
            ),
          ),
          const KeywordWrapSkeleton(
            itemWidths: <double>[86, 72, 94, 68, 88, 76],
          ),
        ] else if (historyKeywords.isNotEmpty) ...<Widget>[
          _SectionHeader(
            title: AppI18n.tByLocaleCode(localeCode, 'search.history.title'),
            trailing: IconButton(
              onPressed: onClearHistory,
              tooltip: AppI18n.tByLocaleCode(localeCode, 'common.clear'),
              icon: const AppSkinIcon(role: AppSkinIconRole.searchHistoryClear),
            ),
          ),
          _KeywordWrap(items: historyKeywords, onTap: onTapKeyword),
        ],
        const SizedBox(height: 14),
        _SectionHeader(
          title: AppI18n.tByLocaleCode(localeCode, 'search.hot.title'),
        ),
        if (loadingHot)
          const HotKeywordListSkeleton()
        else if (hotKeywords.isEmpty)
          _SectionEmpty(
            text: AppI18n.tByLocaleCode(localeCode, 'search.hot.empty'),
          )
        else
          _HotKeywordList(items: hotKeywords, onTap: onTapKeyword),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        if (trailing != null) ...<Widget>[trailing!],
      ],
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}

class _KeywordWrap extends StatelessWidget {
  const _KeywordWrap({required this.items, required this.onTap});

  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => _KeywordTag(label: item, onTap: () => onTap(item)))
          .toList(growable: false),
    );
  }
}

class _KeywordTag extends StatelessWidget {
  const _KeywordTag({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Material(
      color: fill.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
    );
  }
}

class _HotKeywordList extends StatelessWidget {
  const _HotKeywordList({required this.items, required this.onTap});

  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final displayed = items.take(12).toList(growable: false);
    return Column(
      children: displayed
          .asMap()
          .entries
          .map((entry) {
            final rank = entry.key + 1;
            final keyword = entry.value;
            return InkWell(
              onTap: () => onTap(keyword),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$rank',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: rank <= 3
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        keyword,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
