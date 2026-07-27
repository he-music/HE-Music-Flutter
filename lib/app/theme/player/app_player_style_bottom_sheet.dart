import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final playerStyleTheme = inheritedTheme.extension<AppPlayerStyleTheme>();
  final sheetBrightness =
      playerStyleTheme?.sheetBrightness ?? inheritedTheme.brightness;
  final sheet = AppPlayerSheetStyle.forBrightness(sheetBrightness);
  final sheetTheme = buildAppPlayerSheetTheme(sheet, sheetBrightness);
  final systemOverlayStyle = playerStyleTheme?.package.systemOverlayStyle;
  final overlayEntry = systemOverlayStyle == null
      ? null
      : OverlayEntry(
          builder: (_) => Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  key: const ValueKey<String>(
                    'player-system-ui-overlay-style-guard',
                  ),
                  value: systemOverlayStyle,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );

  // Modal route 位于播放器之上，弹层存续期间需要持续提供播放器的系统栏样式。
  if (overlayEntry != null) {
    Overlay.of(context, rootOverlay: true).insert(overlayEntry);
  }
  final sheetFuture = showModalBottomSheet<T>(
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
  if (overlayEntry == null) {
    return sheetFuture;
  }
  return sheetFuture.whenComplete(() {
    overlayEntry
      ..remove()
      ..dispose();
  });
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
