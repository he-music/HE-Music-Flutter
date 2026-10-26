import 'package:flutter/material.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../domain/entities/online_platform.dart';
import '../../../../shared/constants/layout_tokens.dart';
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
              .map((platform) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: LayoutTokens.controlMinExtent,
                  ),
                  child: UnderlineTab(
                    label: platform.label,
                    selected: platform.id == selectedPlatformId,
                    enabled:
                        platform.available &&
                        platform.supports(requiredFeatureFlag),
                    onTap: () => onChanged(platform.id),
                  ),
                );
              })
              .toList(growable: false),
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
