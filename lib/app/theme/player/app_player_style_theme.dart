import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter/cupertino.dart';
import '../../config/app_ui_style.dart';
import '../app_ui_theme.dart';
import 'app_player_style_models.dart';

@immutable
class AppPlayerStyleTheme extends ThemeExtension<AppPlayerStyleTheme> {
  const AppPlayerStyleTheme({
    required this.systemOverlayStyle,
    required this.sheetBrightness,
  });

  final SystemUiOverlayStyle systemOverlayStyle;
  final Brightness sheetBrightness;

  static AppPlayerStyleTheme of(BuildContext context) {
    final theme = Theme.of(context).extension<AppPlayerStyleTheme>();
    assert(theme != null, 'AppPlayerStyleTheme is missing from the player');
    return theme!;
  }

  @override
  AppPlayerStyleTheme copyWith({
    SystemUiOverlayStyle? systemOverlayStyle,
    Brightness? sheetBrightness,
  }) {
    return AppPlayerStyleTheme(
      systemOverlayStyle: systemOverlayStyle ?? this.systemOverlayStyle,
      sheetBrightness: sheetBrightness ?? this.sheetBrightness,
    );
  }

  @override
  AppPlayerStyleTheme lerp(covariant AppPlayerStyleTheme? other, double t) {
    if (other == null) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}

ThemeData buildAppPlayerStyleTheme(
  AppPlayerStyleForegroundColors colors,
  SystemUiOverlayStyle systemOverlayStyle, {
  Brightness sheetBrightness = Brightness.dark,
  AppUiStyle uiStyle = AppUiStyle.material,
}) {
  final sheetStyle = AppPlayerSheetStyle.forBrightness(
    sheetBrightness,
    uiStyle: uiStyle,
  );
  final scheme = ColorScheme.dark(
    primary: colors.accent,
    onPrimary: appPlayerSurfaceColor,
    secondary: colors.accent,
    onSecondary: appPlayerSurfaceColor,
    surface: appPlayerSurfaceColor,
    onSurface: colors.foreground,
    outline: colors.controlBorder,
    outlineVariant: colors.controlBorder,
  );
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    dividerColor: colors.controlBorder,
    iconTheme: IconThemeData(color: colors.foreground),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: colors.accent,
      thumbColor: colors.accent,
      inactiveTrackColor: colors.secondaryForeground.withValues(alpha: 0.24),
    ),
    bottomSheetTheme: buildAppPlayerBottomSheetTheme(sheetStyle),
    extensions: <ThemeExtension<dynamic>>[
      AppUiTheme(style: uiStyle),
      AppPlayerStyleTheme(
        systemOverlayStyle: systemOverlayStyle,
        sheetBrightness: sheetBrightness,
      ),
    ],
  );
}

ThemeData buildAppPlayerSheetTheme(
  AppPlayerSheetStyle style,
  Brightness brightness, {
  AppUiStyle uiStyle = AppUiStyle.material,
  Color? primaryColor,
  Color? onPrimaryColor,
}) {
  final baseScheme = brightness == Brightness.dark
      ? ColorScheme.dark(
          primary: style.foregroundColor,
          onPrimary: style.backgroundColor,
          secondary: style.foregroundColor,
          onSecondary: style.backgroundColor,
          surface: style.backgroundColor,
          onSurface: style.foregroundColor,
          outline: style.secondaryForegroundColor,
          outlineVariant: style.dividerColor,
        )
      : ColorScheme.light(
          primary: style.foregroundColor,
          onPrimary: style.backgroundColor,
          secondary: style.foregroundColor,
          onSecondary: style.backgroundColor,
          surface: style.backgroundColor,
          onSurface: style.foregroundColor,
          outline: style.secondaryForegroundColor,
          outlineVariant: style.dividerColor,
        );
  final scheme = baseScheme.copyWith(
    primary:
        primaryColor ??
        (uiStyle == AppUiStyle.cupertino
            ? CupertinoColors.activeBlue
            : baseScheme.primary),
    onPrimary:
        onPrimaryColor ??
        (uiStyle == AppUiStyle.cupertino
            ? CupertinoColors.white
            : baseScheme.onPrimary),
    onSurfaceVariant: style.secondaryForegroundColor,
    surfaceContainerLowest: style.backgroundColor,
    surfaceContainerLow: style.backgroundColor,
    surfaceContainer: style.backgroundColor,
    surfaceContainerHigh: style.backgroundColor,
    surfaceContainerHighest: style.backgroundColor,
    surfaceTint: Colors.transparent,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final cupertino = CupertinoTextThemeData(primaryColor: scheme.primary);
  final textTheme = uiStyle == AppUiStyle.cupertino
      ? base.textTheme.merge(
          TextTheme(
            titleLarge: cupertino.navTitleTextStyle.copyWith(
              inherit: true,
              color: style.foregroundColor,
            ),
            titleMedium: cupertino.navTitleTextStyle.copyWith(
              inherit: true,
              color: style.foregroundColor,
            ),
            titleSmall: cupertino.navTitleTextStyle.copyWith(
              inherit: true,
              color: style.foregroundColor,
            ),
            bodyLarge: cupertino.textStyle.copyWith(
              inherit: true,
              color: style.foregroundColor,
            ),
            bodyMedium: cupertino.textStyle.copyWith(
              inherit: true,
              color: style.foregroundColor,
            ),
            bodySmall: cupertino.textStyle.copyWith(
              inherit: true,
              fontSize: 13,
              color: style.secondaryForegroundColor,
            ),
            labelLarge: cupertino.actionTextStyle.copyWith(inherit: true),
          ),
        )
      : base.textTheme;
  return base.copyWith(
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[AppUiTheme(style: uiStyle)],
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: scheme.primary,
      primaryContrastingColor: scheme.onPrimary,
      scaffoldBackgroundColor: style.backgroundColor,
      barBackgroundColor: style.backgroundColor,
      textTheme: CupertinoTextThemeData(
        primaryColor: scheme.primary,
        textStyle: textTheme.bodyMedium!.copyWith(color: style.foregroundColor),
        actionTextStyle: textTheme.labelLarge!.copyWith(color: scheme.primary),
      ),
    ),
    scaffoldBackgroundColor: style.backgroundColor,
    canvasColor: style.backgroundColor,
    dividerColor: style.dividerColor,
    iconTheme: IconThemeData(color: style.foregroundColor),
    listTileTheme: ListTileThemeData(
      iconColor: style.foregroundColor,
      textColor: style.foregroundColor,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: style.foregroundColor,
      thumbColor: style.foregroundColor,
      inactiveTrackColor: style.secondaryForegroundColor.withValues(alpha: 0.3),
    ),
    bottomSheetTheme: buildAppPlayerBottomSheetTheme(style),
  );
}

BottomSheetThemeData buildAppPlayerBottomSheetTheme(AppPlayerSheetStyle style) {
  return BottomSheetThemeData(
    backgroundColor: style.backgroundColor,
    surfaceTintColor: Colors.transparent,
    modalBackgroundColor: style.backgroundColor,
    modalBarrierColor: Colors.black.withValues(alpha: 0.54),
    dragHandleColor: style.handleColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(style.topRadius),
      ),
    ),
  );
}
