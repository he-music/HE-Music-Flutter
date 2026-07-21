import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config_controller.dart';
import 'app_player_style_registry.dart';
import 'app_player_style_theme.dart';

class AppPlayerStyleBoundary extends ConsumerWidget {
  const AppPlayerStyleBoundary({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styleId = ref.watch(
      appConfigProvider.select((config) => config.playerStyleId),
    );
    final package = AppPlayerStyleRegistry.instance.resolve(styleId);
    final theme = buildAppPlayerStyleTheme(
      package,
      sheetBrightness: Theme.of(context).brightness,
    );
    return AnnotatedRegion(
      value: package.systemOverlayStyle,
      child: Theme(
        key: const ValueKey<String>('app-player-style-boundary'),
        data: theme,
        child: child,
      ),
    );
  }
}
