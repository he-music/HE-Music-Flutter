import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_ui_theme.dart';

/// A form keeps its route's dismissal policy and keyboard avoidance.
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
    if (!AppUiTheme.usesCupertino(context)) {
      return Dialog(insetPadding: insetPadding, child: child);
    }
    return Dialog(
      insetPadding: insetPadding,
      backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: child,
    );
  }
}
