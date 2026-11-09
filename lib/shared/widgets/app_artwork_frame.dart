import 'package:flutter/material.dart';

import '../../app/theme/app_ui_theme.dart';

/// A quiet artwork edge shared by collections, song rows and detail headers.
/// The frame never changes the artwork's constraints or interaction area.
class AppArtworkFrame extends StatelessWidget {
  const AppArtworkFrame({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.showShadow = false,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cupertino = AppUiTheme.usesCupertino(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: showShadow && !cupertino
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.18 : 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : const <BoxShadow>[],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        border: cupertino
            ? null
            : Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.14)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                width: 0.7,
              ),
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}
