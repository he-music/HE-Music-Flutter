import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/theme/glass/app_glass_material.dart';
import '../../app/theme/glass/app_glass_scope.dart';

/// A floating form surface; children remain ordinary controls, avoiding
/// nested refractive surfaces. The route keeps its existing dismissal policy.
class AppFormDialog extends StatelessWidget {
  const AppFormDialog({
    required this.child,
    this.insetPadding = const EdgeInsets.all(24),
    super.key,
  });

  final Widget child;
  final EdgeInsets insetPadding;

  @override
  Widget build(BuildContext context) {
    if (!AppGlassScope.controlsEnabled(context)) {
      return Dialog(insetPadding: insetPadding, child: child);
    }
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding:
              insetPadding +
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: GlassCard(
              useOwnLayer: true,
              padding: EdgeInsets.zero,
              settings: AppGlassMaterial.sheetFor(context),
              quality: AppGlassScope.qualityOf(context),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
