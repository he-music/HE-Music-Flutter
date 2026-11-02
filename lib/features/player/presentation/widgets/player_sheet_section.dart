import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';

/// Optional item backgrounds inside an always-opaque player modal surface.
class PlayerSheetSection extends ConsumerWidget {
  const PlayerSheetSection({
    required this.children,
    this.title,
    this.hasLeading = true,
    super.key,
  });

  final List<Widget> children;
  final String? title;
  final bool hasLeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBackground = ref.watch(
      appConfigProvider.select((config) => config.showContentBackground),
    );
    final theme = Theme.of(context);
    return CupertinoListSection.insetGrouped(
      margin: const EdgeInsets.only(bottom: 12),
      hasLeading: hasLeading,
      backgroundColor: Colors.transparent,
      header: title == null
          ? null
          : Semantics(
              header: true,
              child: Text(
                title!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
      decoration: BoxDecoration(
        color: showBackground
            ? Color.alphaBlend(
                theme.colorScheme.onSurface.withValues(alpha: 0.04),
                theme.colorScheme.surface,
              )
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      children: children,
    );
  }
}
