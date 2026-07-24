import 'package:flutter/material.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/skin/app_skin_icon.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../domain/entities/online_platform.dart';
import '../../../../shared/widgets/plaza_loading_skeleton.dart';
import '../../../../shared/widgets/underline_tab.dart';
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = theme.colorScheme.surface.withValues(alpha: 0.92);
    final borderRadius = BorderRadius.circular(16);
    final secondary = placeholderSecondary?.trim() ?? '';
    return SizedBox(
      height: 42,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          return Stack(
            children: <Widget>[
              TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: fill,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: borderRadius,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: borderRadius,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: borderRadius,
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                  prefixIcon: AppSkinIcon(
                    role: AppSkinIconRole.search,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  suffixIcon: value.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                          icon: AppSkinIcon(
                            role: AppSkinIconRole.close,
                            size: 18,
                            color: theme.hintColor,
                          ),
                        ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                onChanged: onChanged,
                onSubmitted: (_) => onSubmit(),
              ),
              if (value.text.trim().isEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(42, 0, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: placeholderPrimary,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.72,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (secondary.isNotEmpty)
                                TextSpan(
                                  text: ' $secondary',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types
            .map(
              (tab) => _SimpleTab(
                label: AppI18n.tByLocaleCode(localeCode, tab.labelKey),
                selected: selectedType == tab,
                onTap: () => onChanged(tab),
              ),
            )
            .toList(growable: false),
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
      return const PlazaPlatformTabsSkeleton();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: platforms
              .map((platform) {
                return _PlatformChip(
                  label: platform.label,
                  selected: platform.id == selectedPlatformId,
                  enabled: platform.supports(requiredFeatureFlag),
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
    final baseTextColor = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? selectedColor.withValues(alpha: 0.10)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: !enabled
                    ? theme.hintColor.withValues(alpha: 0.55)
                    : (selected ? selectedColor : baseTextColor),
              ),
            ),
          ),
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
