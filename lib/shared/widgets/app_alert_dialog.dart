import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_ui_theme.dart';

/// Preserves rich/disabled actions while using each design's alert semantics.
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.scrollable = false,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (!AppUiTheme.usesCupertino(context)) {
      return AlertDialog(
        title: title,
        content: content,
        actions: actions,
        scrollable: scrollable,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return CupertinoAlertDialog(
      title: title,
      content: content == null
          ? null
          : Material(type: MaterialType.transparency, child: content),
      actions: [
        for (final action in actions ?? const <Widget>[])
          if (action is ButtonStyleButton)
            CupertinoDialogAction(
              onPressed: action.onPressed,
              isDefaultAction: action is FilledButton,
              isDestructiveAction:
                  action.style?.foregroundColor?.resolve({}) == colors.error,
              child: action.child ?? const SizedBox.shrink(),
            )
          else
            action,
      ],
    );
  }
}
