import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../models/he_music_models.dart';

/// 平台加载失败提示行。
class PlazaPlatformsErrorView extends ConsumerWidget {
  const PlazaPlatformsErrorView({
    required this.onRetry,
    required this.i18nKey,
    super.key,
  });

  final VoidCallback onRetry;
  final String i18nKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return SizedBox(
      height: 28,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              AppI18n.t(config, i18nKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(AppI18n.t(config, 'common.retry')),
          ),
        ],
      ),
    );
  }
}

/// 居中错误信息 + 重试按钮。
class PlazaErrorView extends ConsumerWidget {
  const PlazaErrorView({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(AppI18n.t(config, 'common.retry')),
            ),
          ],
        ),
      ),
    );
  }
}

/// 居中空状态文本。
class PlazaEmptyState extends StatelessWidget {
  const PlazaEmptyState({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}

/// 加载更多失败重试卡片。
class PlazaLoadMoreRetryCard extends ConsumerWidget {
  const PlazaLoadMoreRetryCard({
    required this.message,
    required this.onRetry,
    required this.fallbackI18nKey,
    super.key,
  });

  final String? message;
  final VoidCallback onRetry;
  final String fallbackI18nKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: <Widget>[
          Text(
            message?.trim().isNotEmpty == true
                ? message!.trim()
                : AppI18n.t(config, fallbackI18nKey),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: onRetry,
            child: Text(AppI18n.t(config, 'common.retry')),
          ),
        ],
      ),
    );
  }
}

/// 过滤器 ChoiceChip 行（用于 Artist、Video 的 FilterInfo 过滤面板）。
class PlazaFilterChipRow extends StatelessWidget {
  const PlazaFilterChipRow({
    required this.group,
    required this.selectedValue,
    required this.onSelect,
    super.key,
  });

  final FilterInfo group;
  final String? selectedValue;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: group.options
              .map((option) {
                final selected = option.value == selectedValue;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(option.label),
                    showCheckmark: false,
                    selected: selected,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    selectedColor: colorScheme.primary.withValues(alpha: 0.10),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    side: BorderSide(
                      width: 0.9,
                      color: selected
                          ? colorScheme.primary.withValues(alpha: 0.30)
                          : colorScheme.outlineVariant,
                    ),
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 0,
                    ),
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -3,
                    ),
                    onSelected: (_) => onSelect(option.value),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

/// 过滤面板（多行 FilterInfo ChoiceChip）。
class PlazaFiltersPanel extends StatelessWidget {
  const PlazaFiltersPanel({
    required this.filterGroups,
    required this.selectedFilters,
    required this.onSelectFilter,
    super.key,
  });

  final List<FilterInfo> filterGroups;
  final Map<String, String> selectedFilters;
  final void Function(String groupId, String value) onSelectFilter;

  @override
  Widget build(BuildContext context) {
    if (filterGroups.isEmpty) {
      return const SizedBox.shrink();
    }
    final visibleGroups = filterGroups
        .where((group) => group.options.isNotEmpty)
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: visibleGroups
              .asMap()
              .entries
              .map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == visibleGroups.length - 1 ? 0 : 6,
                  ),
                  child: PlazaFilterChipRow(
                    group: entry.value,
                    selectedValue: selectedFilters[entry.value.id],
                    onSelect: (value) => onSelectFilter(entry.value.id, value),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}
