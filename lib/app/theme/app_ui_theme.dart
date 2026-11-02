import 'package:flutter/material.dart';

import '../config/app_ui_style.dart';

/// Carries the user's design choice without spoofing the operating system.
@immutable
class AppUiTheme extends ThemeExtension<AppUiTheme> {
  const AppUiTheme({this.style = AppUiStyle.material});

  final AppUiStyle style;

  static bool usesCupertino(BuildContext context) =>
      (context.dependOnInheritedWidgetOfExactType<AppUiStyleScope>()?.style ??
          Theme.of(context).extension<AppUiTheme>()?.style) ==
      AppUiStyle.cupertino;

  @override
  AppUiTheme copyWith({AppUiStyle? style}) =>
      AppUiTheme(style: style ?? this.style);

  @override
  AppUiTheme lerp(covariant AppUiTheme? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// Keeps the design choice available through local player and sheet themes.
class AppUiStyleScope extends InheritedWidget {
  const AppUiStyleScope({required this.style, required super.child, super.key});

  final AppUiStyle style;

  @override
  bool updateShouldNotify(AppUiStyleScope oldWidget) =>
      style != oldWidget.style;
}
