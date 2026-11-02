import 'package:flutter/foundation.dart';

/// Widget design language, independent of skin, brightness and device platform.
enum AppUiStyle {
  material,
  cupertino;

  static AppUiStyle parse(String? value) =>
      values.where((style) => style.name == value).firstOrNull ?? material;
}

/// Source used to resolve the application's design language.
enum AppUiStylePreference {
  platform,
  material,
  cupertino;

  static AppUiStylePreference parse(String? value) =>
      values.where((preference) => preference.name == value).firstOrNull ??
      platform;

  AppUiStyle resolve(TargetPlatform platform) {
    return switch (this) {
      AppUiStylePreference.platform =>
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
            ? AppUiStyle.cupertino
            : AppUiStyle.material,
      AppUiStylePreference.material => AppUiStyle.material,
      AppUiStylePreference.cupertino => AppUiStyle.cupertino,
    };
  }
}
