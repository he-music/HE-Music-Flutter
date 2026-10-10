import 'package:flutter/material.dart';

/// Status text colors follow app brightness and participate in theme transitions.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.warning,
    required this.info,
  });

  factory AppStatusColors.fromScheme(ColorScheme scheme) => AppStatusColors(
    success: _foreground(const Color(0xFF2F9A5A), scheme.brightness),
    warning: _foreground(const Color(0xFFCF8A17), scheme.brightness),
    info: _foreground(const Color(0xFF278BCB), scheme.brightness),
  );

  final Color success;
  final Color warning;
  final Color info;

  static Color _foreground(Color seed, Brightness brightness) =>
      ColorScheme.fromSeed(seedColor: seed, brightness: brightness).primary;

  static AppStatusColors of(BuildContext context) =>
      Theme.of(context).extension<AppStatusColors>() ??
      AppStatusColors.fromScheme(Theme.of(context).colorScheme);

  @override
  AppStatusColors copyWith({Color? success, Color? warning, Color? info}) =>
      AppStatusColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        info: info ?? this.info,
      );

  @override
  AppStatusColors lerp(covariant AppStatusColors? other, double t) =>
      other == null
      ? this
      : AppStatusColors(
          success: Color.lerp(success, other.success, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
          info: Color.lerp(info, other.info, t)!,
        );
}
