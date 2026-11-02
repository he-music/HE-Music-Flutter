import 'package:flutter/material.dart';

import '../../app/i18n/app_i18n.dart';
import 'app_button.dart';

/// A fixed heading and an explicit exit for immediately applied sheet choices.
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    required this.title,
    this.actionLabel,
    this.padding = const EdgeInsetsDirectional.only(start: 16, end: 4),
    super.key,
  });

  final String title;
  final String? actionLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        AppButton.text(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            actionLabel ??
                AppI18n.tByLocaleCode(
                  Localizations.localeOf(context).languageCode,
                  'common.done',
                ),
          ),
        ),
      ],
    ),
  );
}
