import 'package:flutter/gestures.dart';
import '../shared/widgets/app_scrollbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_ui_style.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior({this.uiStyle = AppUiStyle.material});

  final AppUiStyle uiStyle;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      uiStyle == AppUiStyle.cupertino
      ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
      : super.getScrollPhysics(context);

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => uiStyle == AppUiStyle.cupertino
      ? child
      : super.buildOverscrollIndicator(context, child, details);

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => switch (getPlatform(context)) {
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => AppScrollbar(
      controller: details.controller,
      uiStyle: uiStyle,
      child: child,
    ),
    _ => child,
  };
  @override
  bool shouldNotify(covariant AppScrollBehavior oldDelegate) =>
      uiStyle != oldDelegate.uiStyle || super.shouldNotify(oldDelegate);

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };

  @override
  Set<LogicalKeyboardKey> get pointerAxisModifiers => <LogicalKeyboardKey>{
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
  };
}
