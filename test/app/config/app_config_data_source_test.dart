import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_online_audio_quality.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/config/app_theme_mode.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
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
        skinId: AppSkinRegistry.citySoundCreatorId,
        enableSkinAnimation: false,
        isMonochrome: true,
        localeCode: 'en',
        onlineAudioQualityPreference: AppOnlineAudioQuality.flac,
        lastSelectedOnlineAudioQualityName: 'sq',
        autoCheckUpdates: true,
        playerStyleId: AppPlayerStyleRegistry.vinylId,
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
    expect(state.skinId, AppSkinRegistry.citySoundCreatorId);
    expect(state.enableSkinAnimation, isFalse);
    expect(state.isMonochrome, isTrue);
    expect(state.localeCode, 'en');
    expect(state.onlineAudioQualityPreference, AppOnlineAudioQuality.flac);
    expect(state.lastSelectedOnlineAudioQualityName, 'sq');
    expect(state.autoCheckUpdates, isTrue);
    expect(state.playerStyleId, AppPlayerStyleRegistry.vinylId);
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
    expect(state.playerStyleId, AppPlayerStyleRegistry.classicId);
    expect(state.enableWordByWordLyric, isTrue);
    expect(state.skinId, AppSkinRegistry.classicId);
    expect(state.enableSkinAnimation, isTrue);
  });

  test('load should normalize and persist an unknown skin id', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_config.skin_id': 'removed_skin',
      'app_config.theme_accent': AppThemeAccent.rose.value,
    });
    const dataSource = AppConfigDataSource();

    final state = await dataSource.load();
    final prefs = await SharedPreferences.getInstance();

    expect(state.skinId, AppSkinRegistry.classicId);
    expect(state.themeAccent, AppThemeAccent.rose);
    expect(prefs.getString('app_config.skin_id'), AppSkinRegistry.classicId);
  });

  test('skin round trip preserves the manual theme accent', () async {
    const dataSource = AppConfigDataSource();
    await dataSource.save(
      AppConfigState.initial.copyWith(
        skinId: AppSkinRegistry.citySoundCreatorId,
        themeAccent: AppThemeAccent.amber,
      ),
    );

    final immersive = await dataSource.load();
    await dataSource.save(
      immersive.copyWith(skinId: AppSkinRegistry.classicId),
    );
    final classic = await dataSource.load();

    expect(classic.skinId, AppSkinRegistry.classicId);
    expect(classic.themeAccent, AppThemeAccent.amber);
  });

  test('legacy player background does not migrate to a player style', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_config.player_background_style': 'artist_photo',
    });
    const dataSource = AppConfigDataSource();

    final state = await dataSource.load();
    final prefs = await SharedPreferences.getInstance();

    expect(state.playerStyleId, AppPlayerStyleRegistry.classicId);
    expect(
      prefs.getString('app_config.player_style_id'),
      AppPlayerStyleRegistry.classicId,
    );
    expect(
      prefs.getString('app_config.player_background_style'),
      'artist_photo',
    );
  });

  test('load normalizes and persists an unknown player style id', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_config.player_style_id': 'removed_style',
    });
    const dataSource = AppConfigDataSource();

    final state = await dataSource.load();
    final prefs = await SharedPreferences.getInstance();

    expect(state.playerStyleId, AppPlayerStyleRegistry.classicId);
    expect(
      prefs.getString('app_config.player_style_id'),
      AppPlayerStyleRegistry.classicId,
    );
  });

  test('saveTokens only updates the token triplet', () async {
    const dataSource = AppConfigDataSource();
    await dataSource.save(
      AppConfigState.initial.copyWith(
        themeMode: AppThemeMode.dark,
        authToken: 'expired-token',
        refreshToken: 'old-refresh-token',
        tokenExpiresAt: 1,
      ),
    );

    await dataSource.saveTokens('fresh-token', 'fresh-refresh-token', 123);
    final state = await dataSource.load();

    expect(state.themeMode, AppThemeMode.dark);
    expect(state.authToken, 'fresh-token');
    expect(state.refreshToken, 'fresh-refresh-token');
    expect(state.tokenExpiresAt, 123);
  });
}
