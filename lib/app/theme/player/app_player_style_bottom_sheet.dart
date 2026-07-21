import 'package:flutter/material.dart';

import 'app_player_style_models.dart';
import 'app_player_style_theme.dart';

Future<T?> showPlayerStyledBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool useSafeArea = true,
  bool isScrollControlled = false,
  bool showDragHandle = true,
}) {
  final inheritedTheme = Theme.of(context);
  final sheetBrightness =
      inheritedTheme.extension<AppPlayerStyleTheme>()?.sheetBrightness ??
      inheritedTheme.brightness;
  final sheet = AppPlayerSheetStyle.forBrightness(sheetBrightness);
  final sheetTheme = buildAppPlayerSheetTheme(sheet, sheetBrightness);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    backgroundColor: sheet.backgroundColor,
    barrierColor: Colors.black.withValues(alpha: 0.54),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(sheet.topRadius),
      ),
    ),
    builder: (sheetContext) => Theme(
      data: sheetTheme,
      child: PlayerSheetSurface(
        style: sheet,
        child: Builder(builder: builder),
      ),
    ),
  );
}

class PlayerSheetSurface extends StatelessWidget {
  const PlayerSheetSurface({
    required this.style,
    required this.child,
    super.key,
  });

  final AppPlayerSheetStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const ValueKey<String>('player-sheet-surface'),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(style.topRadius),
      ),
      child: ColoredBox(
        color: style.backgroundColor,
        child: IconTheme(
          data: IconThemeData(color: style.foregroundColor),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: style.foregroundColor),
            child: child,
          ),
        ),
      ),
    );
  }
}
