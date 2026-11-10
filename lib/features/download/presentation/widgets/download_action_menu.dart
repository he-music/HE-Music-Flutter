import 'package:flutter/material.dart';

import '../../../../app/theme/app_ui_theme.dart';
import '../../../../app/theme/skin/app_skin_bottom_sheet.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/utils/platform_utils.dart';
import '../../../../shared/widgets/adaptive_action_menu.dart';

Future<T?> showDownloadActionMenu<T>({
  required BuildContext context,
  required List<AdaptiveActionMenuItem<T>> items,
  required String title,
}) {
  if (shouldUseDesktopMenu(context) || AppUiTheme.usesCupertino(context)) {
    return showAdaptiveActionMenu<T>(
      context: context,
      items: items,
      title: Text(title),
    );
  }
  return showAppThemedBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final maxHeight =
          MediaQuery.of(sheetContext).size.height *
          LayoutTokens.actionSheetMaxHeightFactor;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 8),
            children: <Widget>[
              for (final item in items)
                ListTile(
                  key: item.key,
                  leading: item.icon == null
                      ? null
                      : Icon(
                          item.icon,
                          color: item.destructive
                              ? Theme.of(sheetContext).colorScheme.error
                              : null,
                        ),
                  enabled: item.enabled,
                  title: Text(
                    item.label,
                    style: item.destructive
                        ? TextStyle(
                            color: Theme.of(sheetContext).colorScheme.error,
                          )
                        : null,
                  ),
                  onTap: item.enabled
                      ? () => Navigator.of(sheetContext).pop(item.value)
                      : null,
                ),
            ],
          ),
        ),
      );
    },
  );
}
