import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config_controller.dart';

/// Optional content fill inside a modal whose outer surface stays opaque.
class AppCupertinoContentSection extends ConsumerWidget {
  const AppCupertinoContentSection({
    required this.children,
    this.header,
    this.hasLeading = true,
    this.margin = EdgeInsets.zero,
    this.backgroundColor,
    super.key,
  });

  final List<Widget> children;
  final Widget? header;
  final bool hasLeading;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBackground = ref.watch(
      appConfigProvider.select((config) => config.showContentBackground),
    );
    final theme = Theme.of(context);
    return CupertinoListSection.insetGrouped(
      margin: margin,
      hasLeading: hasLeading,
      header: header,
      backgroundColor: Colors.transparent,
      decoration: BoxDecoration(
        color: showBackground
            ? backgroundColor ??
                  Color.alphaBlend(
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
