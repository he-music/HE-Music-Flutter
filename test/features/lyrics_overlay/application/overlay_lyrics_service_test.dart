import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/features/lyrics_overlay/application/overlay_lyrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isActive returns false when overlay plugin is unavailable', () async {
    final service = OverlayLyricsService();

    await expectLater(service.isActive(), completion(isFalse));
  });

  test('close is a no-op when overlay plugin is unavailable', () async {
    final service = OverlayLyricsService();

    await expectLater(service.close(), completes);
  });

  test('auto highlight uses the color extracted from current artwork', () {
    final config = AppConfigState.initial.copyWith(
      lyricHighlightMode: AppLyricHighlightMode.auto,
    );

    final color = resolveOverlayLyricHighlightColor(
      config,
      autoHighlightColorValue: Colors.green.toARGB32(),
    );

    expect(color, Colors.green.toARGB32());
  });

  test('auto highlight falls back to sky when artwork has no color', () {
    final config = AppConfigState.initial.copyWith(
      lyricHighlightMode: AppLyricHighlightMode.auto,
    );

    final color = resolveOverlayLyricHighlightColor(config);

    expect(color, AppLyricHighlightColor.sky.color.toARGB32());
  });
}
