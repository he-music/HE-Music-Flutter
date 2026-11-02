import 'package:flutter/material.dart';
import '../app_ui_theme.dart';
import 'app_skin_theme.dart';

Future<T?> showAppThemedBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool useSafeArea = true,
  bool isScrollControlled = false,
  bool showDragHandle = true,
  double heightFactor = 0.45,
  bool fitContent = false,
  // Optional single resting height, shared across rendering modes.
  double? fixedHeightFactor,
}) {
  final theme = Theme.of(context);
  final config = theme.extension<AppSkinTheme>()?.config;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    isScrollControlled:
        fitContent || fixedHeightFactor != null || isScrollControlled,
    constraints: fixedHeightFactor == null
        ? BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * heightFactor,
          )
        : null,
    showDragHandle: showDragHandle,
    backgroundColor:
        (config?.colors.bottomSheetBackground ?? theme.colorScheme.surface)
            .withValues(alpha: 1),
    shape: config == null
        ? null
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(
                AppUiTheme.usesCupertino(context)
                    ? 16
                    : config.geometry.bottomSheetRadius,
              ),
            ),
          ),
    builder: (sheetContext) => fixedHeightFactor == null
        ? builder(sheetContext)
        : FractionallySizedBox(
            heightFactor: fixedHeightFactor,
            child: Builder(builder: builder),
          ),
  );
}
