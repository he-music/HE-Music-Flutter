import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/app/config/app_player_background_style.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_online_audio_quality.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/config/app_theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('load should return saved config values', () async {
    const dataSource = AppConfigDataSource();
    await dataSource.save(
      AppConfigState.initial.copyWith(
        themeMode: AppThemeMode.dark,
        themeAccent: AppThemeAccent.ocean,
        isMonochrome: true,
        localeCode: 'en',
        onlineAudioQualityPreference: AppOnlineAudioQuality.flac,
        lastSelectedOnlineAudioQualityName: 'sq',
        autoCheckUpdates: true,
        playerBackgroundStyle: AppPlayerBackgroundStyle.fluid,
        lyricHighlightMode: AppLyricHighlightMode.custom,
        lyricHighlightPreset: AppLyricHighlightColor.sky,
        lyricHighlightCustomColor: 0xFF123456,
        lyricFontPreset: AppLyricFontPreset.large,
        enableWordByWordLyric: true,
        authToken: 'token',
      ),
    );

    final state = await dataSource.load();

    expect(state.themeMode, AppThemeMode.dark);
    expect(state.themeAccent, AppThemeAccent.ocean);
    expect(state.isMonochrome, isTrue);
    expect(state.localeCode, 'en');
    expect(state.onlineAudioQualityPreference, AppOnlineAudioQuality.flac);
    expect(state.lastSelectedOnlineAudioQualityName, 'sq');
    expect(state.autoCheckUpdates, isTrue);
    expect(state.playerBackgroundStyle, AppPlayerBackgroundStyle.fluid);
    expect(state.lyricHighlightMode, AppLyricHighlightMode.custom);
    expect(state.lyricHighlightPreset, AppLyricHighlightColor.sky);
    expect(state.lyricHighlightCustomColor, 0xFF123456);
    expect(state.lyricFontPreset, AppLyricFontPreset.large);
    expect(state.enableWordByWordLyric, isTrue);
    expect(state.authToken, 'token');
  });

  test('load should keep system locale preference', () async {
    const dataSource = AppConfigDataSource();
    await dataSource.save(
      AppConfigState.initial.copyWith(localeCode: 'system'),
    );

    final state = await dataSource.load();

    expect(state.localeCode, 'system');
  });

  test(
    'load should read legacy lyric highlight color as preset mode',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_config.lyric_highlight_color': 'amber',
      });
      const dataSource = AppConfigDataSource();

      final state = await dataSource.load();

      expect(state.lyricHighlightMode, AppLyricHighlightMode.preset);
      expect(state.lyricHighlightPreset, AppLyricHighlightColor.amber);
      expect(state.lyricHighlightCustomColor, isNull);
    },
  );

  test('load should enable default toggles by default', () async {
    const dataSource = AppConfigDataSource();

    final state = await dataSource.load();

    expect(state.autoCheckUpdates, isTrue);
    expect(state.lyricHighlightMode, AppConfigState.initial.lyricHighlightMode);
    expect(
      state.lyricHighlightPreset,
      AppConfigState.initial.lyricHighlightPreset,
    );
    expect(state.lyricFontPreset, AppConfigState.initial.lyricFontPreset);
    expect(
      state.playerBackgroundStyle,
      AppConfigState.initial.playerBackgroundStyle,
    );
    expect(state.enableWordByWordLyric, isTrue);
  });

  test(
    'load should fallback player background style to default on invalid data',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_config.player_background_style': 'unknown',
      });
      const dataSource = AppConfigDataSource();

      final state = await dataSource.load();

      expect(state.playerBackgroundStyle, AppPlayerBackgroundStyle.albumCover);
    },
  );
}
