import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../domain/entities/online_platform.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../app/theme/app_ui_theme.dart';
import '../../../../shared/widgets/plaza_loading_skeleton.dart';
import '../../../../shared/widgets/underline_tab.dart';
import '../../../../shared/widgets/app_search_field.dart';
import 'online_search_models.dart';

class SearchTopBox extends StatelessWidget {
  const SearchTopBox({
    required this.controller,
    required this.placeholderPrimary,
    required this.onSubmit,
    required this.onChanged,
    this.placeholderSecondary,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final String placeholderPrimary;
  final String? placeholderSecondary;
  final Future<void> Function() onSubmit;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => AppSearchField(
    controller: controller,
    focusNode: focusNode,
    autofocus: true,
    placeholderPrimary: placeholderPrimary,
    placeholderSecondary: placeholderSecondary,
    onChanged: onChanged,
    onSubmitted: (_) => onSubmit(),
  );
}

class SearchTypeBar extends StatelessWidget {
  const SearchTypeBar({
    required this.localeCode,
    required this.selectedType,
    required this.types,
    required this.onChanged,
    super.key,
  });

  final String localeCode;
  final SearchType selectedType;
  final List<SearchType> types;
  final ValueChanged<SearchType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutTokens.compactPageGutter,
        ),
        child: Row(
          children: [
            for (final tab in types)
              _SimpleTab(
                label: AppI18n.tByLocaleCode(localeCode, tab.labelKey),
                selected: selectedType == tab,
                onTap: () => onChanged(tab),
              ),
          ],
        ),
      ),
    );
  }
}

class SearchPlatformBar extends StatelessWidget {
  const SearchPlatformBar({
    required this.loading,
    required this.platforms,
    required this.requiredFeatureFlag,
    required this.selectedPlatformId,
    required this.onChanged,
    super.key,
  });

  final bool loading;
  final List<SearchPlatform> platforms;
  final BigInt requiredFeatureFlag;
  final String selectedPlatformId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (loading && platforms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: LayoutTokens.compactPageGutter,
        ),
        child: PlazaPlatformTabsSkeleton(),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutTokens.compactPageGutter,
        ),
        child: Row(
          children: platforms
              .where(
                (platform) =>
                    platform.available &&
                    platform.supports(requiredFeatureFlag),
              )
              .map((platform) {
                return _PlatformChip(
                  label: platform.label,
                  selected: platform.id == selectedPlatformId,
                  enabled: platform.available,
                  onTap: () => onChanged(platform.id),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final isCupertino = AppUiTheme.usesCupertino(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: !enabled
          ? theme.hintColor.withValues(alpha: 0.55)
          : selected
          ? selectedColor
          : theme.colorScheme.onSurfaceVariant,
    );
    final control = isCupertino
        ? CupertinoButton(
            onPressed: enabled ? onTap : null,
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: selected ? selectedColor.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(999),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          )
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(999),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: selected
                          ? selectedColor.withValues(alpha: 0.10)
                          : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: Text(label, style: labelStyle),
                    ),
                  ),
                ),
              ),
            ),
          );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: MergeSemantics(
        child: Semantics(
          button: true,
          selected: selected,
          enabled: enabled,
          child: control,
        ),
      ),
    );
  }
}

class _SimpleTab extends StatelessWidget {
  const _SimpleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return UnderlineTab(
      label: label,
      selected: selected,
      enabled: true,
      minHeight: AppUiTheme.usesCupertino(context)
          ? 44
          : LayoutTokens.controlMinExtent,
      onTap: onTap,
    );
  }
}

class SearchPlatform {
  const SearchPlatform({
    required this.id,
    required this.label,
    required this.available,
    required this.featureSupportFlag,
  });

  final String id;
  final String label;
  final bool available;
  final BigInt featureSupportFlag;

  bool supports(BigInt flag) {
    return (featureSupportFlag & flag) != BigInt.zero;
  }

  factory SearchPlatform.fromOnlinePlatform(OnlinePlatform platform) {
    return SearchPlatform(
      id: platform.id,
      label: platform.shortName,
      available: platform.available,
      featureSupportFlag: platform.featureSupportFlag,
    );
  }

  factory SearchPlatform.fromMap(Map<String, dynamic> raw) {
    final id = '${raw['id'] ?? ''}'.trim();
    final labelSource = '${raw['shortname'] ?? raw['name'] ?? ''}'.trim();
    final status = int.tryParse('${raw['status'] ?? 0}') ?? 0;
    final featureSupportFlag =
        BigInt.tryParse('${raw['feature_support_flag'] ?? '0'}') ?? BigInt.zero;
    return SearchPlatform(
      id: id.isEmpty ? '-' : id,
      label: labelSource.isEmpty ? id : labelSource,
      available: status == 1,
      featureSupportFlag: featureSupportFlag,
    );
  }
}
