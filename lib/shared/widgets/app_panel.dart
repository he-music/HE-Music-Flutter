import 'package:flutter/material.dart';

import '../../app/theme/app_ui_theme.dart';
import '../../app/theme/skin/app_skin_surface.dart';

/// A lightweight content panel shared by both interface styles.
class AppPanel extends StatelessWidget {
  const AppPanel({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.tintColor,
    this.borderColor,
    this.padding,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color? tintColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (AppUiTheme.usesCupertino(context)) {
      return AppSkinContentSurface(
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              tintColor ??
              (isDark
                  ? Colors.black.withValues(alpha: .22)
                  : Colors.white.withValues(alpha: .48)),
          borderRadius: borderRadius,
          border: Border.all(
            color:
                borderColor ??
                Colors.white.withValues(alpha: isDark ? .14 : .34),
            width: .8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? .18 : .10),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
