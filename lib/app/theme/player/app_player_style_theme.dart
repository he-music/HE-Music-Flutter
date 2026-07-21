import 'package:flutter/material.dart';

import 'app_player_style_models.dart';

@immutable
class AppPlayerStyleTheme extends ThemeExtension<AppPlayerStyleTheme> {
  const AppPlayerStyleTheme({
    required this.package,
    required this.sheetBrightness,
  });

  final AppPlayerStylePackage package;
  final Brightness sheetBrightness;

  static AppPlayerStyleTheme of(BuildContext context) {
    final theme = Theme.of(context).extension<AppPlayerStyleTheme>();
    assert(theme != null, 'AppPlayerStyleTheme is missing from the player');
    return theme!;
  }

  @override
  AppPlayerStyleTheme copyWith({
    AppPlayerStylePackage? package,
    Brightness? sheetBrightness,
  }) {
    return AppPlayerStyleTheme(
      package: package ?? this.package,
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
  AppPlayerStylePackage package, {
  Brightness sheetBrightness = Brightness.dark,
}) {
  final colors = package.colors;
  final sheetStyle = AppPlayerSheetStyle.forBrightness(sheetBrightness);
  final scheme = ColorScheme.dark(
    primary: colors.accent,
    onPrimary: colors.backgroundEnd,
    secondary: colors.accent,
    onSecondary: colors.backgroundEnd,
    surface: colors.backgroundEnd,
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
      AppPlayerStyleTheme(package: package, sheetBrightness: sheetBrightness),
    ],
  );
}

ThemeData buildAppPlayerSheetTheme(
  AppPlayerSheetStyle style,
  Brightness brightness,
) {
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
    onSurfaceVariant: style.secondaryForegroundColor,
    surfaceContainerLowest: style.backgroundColor,
    surfaceContainerLow: style.backgroundColor,
    surfaceContainer: style.backgroundColor,
    surfaceContainerHigh: style.backgroundColor,
    surfaceContainerHighest: style.backgroundColor,
    surfaceTint: Colors.transparent,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
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
