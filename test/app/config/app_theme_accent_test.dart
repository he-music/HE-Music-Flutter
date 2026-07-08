import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';

void main() {
  test('theme accent exposes expanded music-friendly palette', () {
    expect(AppThemeAccent.values.length, greaterThanOrEqualTo(11));
    expect(AppThemeAccent.fromValue('midnight'), AppThemeAccent.midnight);
    expect(AppThemeAccent.fromValue('mint'), AppThemeAccent.mint);
    expect(AppThemeAccent.fromValue('cherry'), AppThemeAccent.cherry);
    expect(AppThemeAccent.fromValue('graphite'), AppThemeAccent.graphite);
  });

  test('theme accent labels and seeds are configured', () {
    for (final accent in AppThemeAccent.values) {
      expect(accent.value.trim(), isNotEmpty);
      expect(accent.label.trim(), isNotEmpty);
      expect(accent.lightSeed, isA<Color>());
      expect(accent.darkSeed, isA<Color>());
    }
  });
}
