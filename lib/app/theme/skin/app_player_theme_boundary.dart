import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config_controller.dart';
import '../app_theme.dart';
import 'app_skin_registry.dart';

class AppPlayerThemeBoundary extends ConsumerWidget {
  const AppPlayerThemeBoundary({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(
      appConfigProvider.select((config) => config.themeAccent),
    );
    final classic = AppSkinRegistry.builtIn(
      accent,
    ).resolve(AppSkinRegistry.classicId);
    final theme = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.dark(classic)
        : AppTheme.light(classic);
    return Theme(
      key: const ValueKey<String>('app-player-theme-boundary'),
      data: theme,
      child: child,
    );
  }
}
