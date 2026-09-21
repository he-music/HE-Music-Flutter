import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/theme/glass/app_glass_material.dart';
import '../../app/theme/glass/app_glass_scope.dart';

/// Adapts the app's simple Material alerts to the native glass dialog.
/// Rich/disabled actions retain Material semantics rather than being flattened
/// into the glass API, which supports only 1–3 enabled text actions.
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

  Widget _materialDialog() => AlertDialog(
    title: title,
    content: content,
    actions: actions,
    scrollable: scrollable,
  );

  @override
  Widget build(BuildContext context) {
    if (!AppGlassScope.controlsEnabled(context)) return _materialDialog();
    final buttons = actions ?? const <Widget>[];
    if (buttons.isEmpty ||
        buttons.length > 3 ||
        (title != null && (title is! Text || (title as Text).data == null)) ||
        buttons.any(
          (button) =>
              button is! ButtonStyleButton ||
              button.onPressed == null ||
              button.child is! Text ||
              (button.child as Text).data == null,
        )) {
      return _materialDialog();
    }
    final colors = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: GlassDialog(
              maxWidth: 360,
              title: (title as Text?)?.data,
              content: content,
              settings: AppGlassMaterial.sheetFor(context),
              quality: AppGlassScope.qualityOf(context),
              actions: [
                for (final action in buttons.cast<ButtonStyleButton>())
                  GlassDialogAction(
                    label: (action.child as Text).data!,
                    onPressed: action.onPressed!,
                    isPrimary: action is FilledButton,
                    isDestructive:
                        action.style?.foregroundColor?.resolve({}) ==
                        colors.error,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
