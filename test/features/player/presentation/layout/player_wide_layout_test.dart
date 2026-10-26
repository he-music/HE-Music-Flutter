import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/presentation/layout/player_wide_layout.dart';

void main() {
  test('wide layout leaves narrow and mobile landscape routing intact', () {
    for (final size in const [
      Size(430, 932),
      Size(768, 1024),
      Size(932, 430),
      Size(999, 800),
      Size(1440, 479),
    ]) {
      expect(
        PlayerWideLayout.supports(size, isMobileLandscape: false),
        isFalse,
        reason: '$size',
      );
    }
    for (final size in const [
      Size(1000, 480),
      Size(1024, 768),
      Size(2560, 1080),
    ]) {
      expect(
        PlayerWideLayout.supports(size, isMobileLandscape: false),
        isTrue,
        reason: '$size',
      );
      expect(
        PlayerWideLayout.supports(size, isMobileLandscape: true),
        isFalse,
        reason: 'existing phone landscape takes precedence at $size',
      );
    }
  });
}
