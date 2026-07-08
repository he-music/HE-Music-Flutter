import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme_accent.dart';

abstract final class AppTheme {
  static ThemeData light(AppThemeAccent accent) =>
      _buildTheme(brightness: Brightness.light, seedColor: accent.lightSeed);

  static ThemeData dark(AppThemeAccent accent) =>
      _buildTheme(brightness: Brightness.dark, seedColor: accent.darkSeed);

  static SystemUiOverlayStyle systemOverlayStyleForBrightness(
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    return (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
        .copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color seedColor,
  }) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    final colorScheme = baseScheme.copyWith(
      surface: _tint(baseScheme.surface, seedColor, isDark ? 0.06 : 0.025),
      surfaceContainer: _tint(
        baseScheme.surfaceContainer,
        seedColor,
        isDark ? 0.08 : 0.035,
      ),
      surfaceContainerHigh: _tint(
        baseScheme.surfaceContainerHigh,
        seedColor,
        isDark ? 0.1 : 0.04,
      ),
      surfaceContainerHighest: _tint(
        baseScheme.surfaceContainerHighest,
        seedColor,
        isDark ? 0.12 : 0.05,
      ),
      primaryContainer: _tint(
        baseScheme.primaryContainer,
        seedColor,
        isDark ? 0.12 : 0.04,
      ),
      secondaryContainer: _tint(
        baseScheme.secondaryContainer,
        seedColor,
        isDark ? 0.08 : 0.03,
      ),
    );
    final baseTextTheme = ThemeData(
      brightness: brightness,
      useMaterial3: true,
    ).textTheme;
    final textTheme = baseTextTheme.copyWith(
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.8,
        height: 1.05,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(height: 1.35),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        height: 1.3,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    );
    final overlayStyle = systemOverlayStyleForBrightness(brightness);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: _tint(
        colorScheme.surface,
        seedColor,
        isDark ? 0.08 : 0.035,
      ),
      canvasColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerHigh.withValues(
          alpha: isDark ? 0.82 : 0.9,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        iconColor: colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.74 : 0.92,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface.withValues(
          alpha: isDark ? 0.94 : 0.96,
        ),
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.9),
        height: 72,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: selected ? 26 : 22,
            color: selected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: colorScheme.outlineVariant),
          foregroundColor: colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _tint(
          isDark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.inverseSurface,
          seedColor,
          isDark ? 0.12 : 0.06,
        ),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
      ),
    );
  }

  static Color _tint(Color base, Color seed, double opacity) {
    return Color.alphaBlend(seed.withValues(alpha: opacity), base);
  }
}
