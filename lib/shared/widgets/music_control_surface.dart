import 'package:flutter/material.dart';

import '../../app/theme/skin/app_skin_theme.dart';

/// Opaque playback/category controls keep scrolling backgrounds inexpensive.
class MusicControlSurface extends StatelessWidget {
  const MusicControlSurface({
    required this.child,
    this.collapseProgress = 1,
    this.borderRadius = 0,
    this.scrollController,
    this.collapseExtent,
    this.joinsCover = false,
    super.key,
  });

  final Widget child;
  final double collapseProgress;
  final double borderRadius;
  final ScrollController? scrollController;
  final double? collapseExtent;
  final bool joinsCover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface =
        theme.extension<AppSkinTheme>()?.config.colors.fixedControlSurface ??
        theme.colorScheme.surface;
    return Material(
      color: surface.withValues(alpha: 1),
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}
