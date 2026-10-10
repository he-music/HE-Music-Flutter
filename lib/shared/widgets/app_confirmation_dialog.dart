import 'package:flutter/material.dart';

import '../../app/i18n/app_i18n.dart';
import 'app_alert_dialog.dart';

Future<bool> confirmAppAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final localeCode = Localizations.localeOf(context).languageCode;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AppAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppI18n.tByLocaleCode(localeCode, 'common.cancel')),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}
