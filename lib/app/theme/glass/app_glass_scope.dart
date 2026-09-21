import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../config/app_config_controller.dart';
import '../../config/app_glass_mode.dart';

/// Main-app glass lifecycle. Standalone widget tests and the lyrics overlay
/// keep using skin surfaces unless they explicitly opt in through this scope.
class AppGlassScope extends InheritedWidget {
  const AppGlassScope({
    required this.enabled,
    this.mode = AppGlassMode.automatic,
    required super.child,
    super.key,
  });

  final bool enabled;
  final AppGlassMode mode;

  static AppGlassMode modeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppGlassScope>()?.mode ??
      AppGlassMode.automatic;

  static bool preferOpaqueSurfaces(BuildContext context) =>
      !modeOf(context).usesGlass;

  /// Power saving keeps only persistent navigation and mini-player glass.
  static bool controlsEnabled(BuildContext context) =>
      isEnabled(context) && modeOf(context).usesGlass;

  /// Automatic requests the highest tier and lets the adaptive ceiling decide.
  /// This product preference deliberately overrides the usual standard control
  /// default: automatic/high may spend more GPU time on popup refraction.
  /// Fixed modes also remain subject to platform/accessibility fallbacks.
  static GlassQuality qualityOf(BuildContext context) => switch (modeOf(
    context,
  )) {
    AppGlassMode.automatic || AppGlassMode.high => GlassQuality.premium,
    AppGlassMode.standard || AppGlassMode.powerSaving => GlassQuality.standard,
    AppGlassMode.low || AppGlassMode.off => GlassQuality.minimal,
  };

  static const configuredEnabled = bool.fromEnvironment(
    'ENABLE_LIQUID_GLASS',
    defaultValue: true,
  );

  static bool isEnabled(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppGlassScope>()?.enabled ??
      false;

  static Future<bool> initialize() async {
    if (!configuredEnabled) return false;
    try {
      await LiquidGlassWidgets.initialize();
      return true;
    } catch (error, stack) {
      // A visual enhancement must not prevent audio startup.
      debugPrint('Liquid glass initialization failed: $error\n$stack');
      return false;
    }
  }

  static Widget wrap({
    required bool enabled,
    required Widget child,
    bool adaptiveQuality = true,
  }) {
    final content = AppGlassScope(enabled: enabled, child: child);
    if (!enabled) return content;
    return LiquidGlassWidgets.wrap(
      adaptiveQuality: adaptiveQuality,
      theme: GlassThemeData.simple(quality: GlassQuality.standard),
      brightnessResolver: Theme.maybeBrightnessOf,
      child: content,
    );
  }

  @override
  bool updateShouldNotify(AppGlassScope oldWidget) =>
      enabled != oldWidget.enabled || mode != oldWidget.mode;
}

/// Keep the app and Navigator mounted while a low-frequency preference changes.
/// Playback ticks and unrelated configuration changes do not rebuild this scope.
class AppGlassPreferences extends ConsumerWidget {
  const AppGlassPreferences({
    required this.available,
    required this.child,
    super.key,
  });

  final bool available;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      appConfigProvider.select((state) => state.glassMode),
    );
    final fixedQuality = switch (mode) {
      AppGlassMode.high => GlassQuality.premium,
      AppGlassMode.standard ||
      AppGlassMode.powerSaving => GlassQuality.standard,
      AppGlassMode.low || AppGlassMode.off => GlassQuality.minimal,
      AppGlassMode.automatic => null,
    };
    return GlassAdaptiveScope(
      initialQuality: fixedQuality ?? GlassQuality.standard,
      minQuality: fixedQuality ?? GlassQuality.minimal,
      maxQuality: fixedQuality ?? GlassQuality.premium,
      allowStepUp: mode == AppGlassMode.automatic,
      child: AppGlassScope(
        enabled: available && mode != AppGlassMode.off,
        mode: mode,
        child: child,
      ),
    );
  }
}
