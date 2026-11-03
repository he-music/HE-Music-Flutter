import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/i18n/app_i18n.dart';
import '../../app/theme/app_ui_theme.dart';
import 'app_adaptive_controls.dart';

/// Dismisses the current sheet without applying or reverting its contents.
class AppSheetCloseButton extends StatelessWidget {
  const AppSheetCloseButton({this.onPressed, this.tooltip, super.key});

  final VoidCallback? onPressed;

  /// Existing Material labels may describe the sheet being closed.
  /// Cupertino consistently announces the localized "Close" action.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cupertino = AppUiTheme.usesCupertino(context);
    return AppIconButton(
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
      tooltip: cupertino
          ? AppI18n.tByLocaleCode(
              Localizations.localeOf(context).languageCode,
              'common.close',
            )
          : tooltip ?? MaterialLocalizations.of(context).closeButtonTooltip,
      color: cupertino
          ? CupertinoColors.secondaryLabel.resolveFrom(context)
          : null,
      icon: Icon(
        cupertino ? CupertinoIcons.xmark_circle_fill : Icons.close_rounded,
        size: cupertino ? 28 : null,
      ),
    );
  }
}
