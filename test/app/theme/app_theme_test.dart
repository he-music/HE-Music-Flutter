import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';

void main() {
  test('light theme uses dark status bar icons', () {
    final overlayStyle = AppTheme.systemOverlayStyleForBrightness(
      Brightness.light,
    );
    final theme = AppTheme.light(AppThemeAccent.cobalt);

    expect(overlayStyle.statusBarIconBrightness, Brightness.dark);
    expect(theme.appBarTheme.systemOverlayStyle, overlayStyle);
    expect(overlayStyle.statusBarBrightness, Brightness.light);
    expect(overlayStyle.statusBarColor, Colors.transparent);
  });

  test('dark theme uses light status bar icons', () {
    final overlayStyle = AppTheme.systemOverlayStyleForBrightness(
      Brightness.dark,
    );
    final theme = AppTheme.dark(AppThemeAccent.cobalt);

    expect(overlayStyle.statusBarIconBrightness, Brightness.light);
    expect(theme.appBarTheme.systemOverlayStyle, overlayStyle);
    expect(overlayStyle.statusBarBrightness, Brightness.dark);
    expect(overlayStyle.statusBarColor, Colors.transparent);
  });
}
