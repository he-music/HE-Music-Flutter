import 'package:flutter/material.dart';

import 'app_skin_theme.dart';

Future<T?> showAppThemedBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool useSafeArea = true,
  bool isScrollControlled = false,
  bool showDragHandle = true,
}) {
  final config = Theme.of(context).extension<AppSkinTheme>()?.config;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    backgroundColor: config?.colors.bottomSheetBackground,
    shape: config == null
        ? null
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(config.geometry.bottomSheetRadius),
            ),
          ),
    builder: builder,
  );
}
