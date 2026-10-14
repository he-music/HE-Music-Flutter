import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../../features/online/domain/entities/online_platform.dart';
import '../constants/layout_tokens.dart';

class OnlinePlatformTabs extends ConsumerWidget {
  const OnlinePlatformTabs({
    required this.platforms,
    required this.selectedId,
    required this.requiredFeatureFlag,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(
      horizontal: LayoutTokens.compactPageGutter,
    ),
    super.key,
  });

  final List<OnlinePlatform> platforms;
  final String? selectedId;
  final BigInt requiredFeatureFlag;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    if (platforms.isEmpty) {
      return Padding(
        padding: padding,
        child: Text(
          AppI18n.t(config, 'ranking.no_platform'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: platforms
              .map(
                (platform) => _UnderlinePlatformTab(
                  label: platform.shortName,
                  selected: platform.id == selectedId,
                  enabled: platform.supports(requiredFeatureFlag),
                  onTap: () => onSelected(platform.id),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _UnderlinePlatformTab extends StatelessWidget {
  const _UnderlinePlatformTab({
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
    final primary = theme.colorScheme.primary;
    final normal = theme.textTheme.bodyMedium?.color;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: !enabled
                    ? theme.hintColor.withValues(alpha: 0.55)
                    : (selected ? primary : normal),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: selected ? 22 : 0,
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: enabled ? primary : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
