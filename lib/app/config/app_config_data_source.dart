import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import 'app_config_state.dart';
import 'app_lyric_font_preset.dart';
import 'app_lyric_highlight_color.dart';
import 'app_lyric_highlight_mode.dart';
import 'app_online_audio_quality.dart';
import 'app_player_background_style.dart';
import 'app_theme_accent.dart';
import 'app_theme_mode.dart';
import '../theme/skin/app_skin_registry.dart';

const _themeModeKey = 'app_config.theme_mode';
const _themeAccentKey = 'app_config.theme_accent';
const _skinIdKey = 'app_config.skin_id';
const _skinAnimationEnabledKey = 'app_config.skin_animation_enabled';
const _monochromeKey = 'app_config.monochrome';
const _localeKey = 'app_config.locale';
const _onlineAudioQualityPreferenceKey =
    'app_config.online_audio_quality_preference';
const _lastSelectedOnlineAudioQualityNameKey =
    'app_config.last_selected_online_audio_quality';
const _autoCheckUpdatesKey = 'app_config.auto_check_updates';
const _playerBackgroundStyleKey = 'app_config.player_background_style';
const _legacyLyricHighlightColorKey = 'app_config.lyric_highlight_color';
const _lyricHighlightModeKey = 'app_config.lyric_highlight_mode';
const _lyricHighlightPresetKey = 'app_config.lyric_highlight_preset';
const _lyricHighlightCustomColorKey = 'app_config.lyric_highlight_custom_color';
const _lyricFontPresetKey = 'app_config.lyric_font_preset';
const _enableWordByWordLyricKey = 'app_config.enable_word_by_word_lyric';
const _enableDesktopLyricKey = 'app_config.enable_desktop_lyric';
const _enableDesktopLyricLockKey = 'app_config.enable_desktop_lyric_lock';
const _authTokenKey = 'app_config.auth_token';
const _refreshTokenKey = 'app_config.refresh_token';
const _tokenExpiresAtKey = 'app_config.token_expires_at';

class AppConfigDataSource {
  const AppConfigDataSource();

  Future<AppConfigState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = _readAuthToken(
      prefs.getString(_authTokenKey),
      hasStoredValue: prefs.containsKey(_authTokenKey),
    );
    final refreshToken = _readAuthToken(
      prefs.getString(_refreshTokenKey),
      hasStoredValue: prefs.containsKey(_refreshTokenKey),
    );
    final tokenExpiresAt = prefs.getInt(_tokenExpiresAtKey);
    final lyricHighlightMode = _readLyricHighlightMode(prefs);
    final skinId = _readSkinId(prefs.getString(_skinIdKey));
    if (prefs.containsKey(_skinIdKey) &&
        prefs.getString(_skinIdKey) != skinId) {
      await prefs.setString(_skinIdKey, skinId);
    }
    return AppConfigState.initial.copyWith(
      themeMode: _readThemeMode(prefs.getString(_themeModeKey)),
      themeAccent: AppThemeAccent.fromValue(prefs.getString(_themeAccentKey)),
      skinId: skinId,
      enableSkinAnimation:
          prefs.getBool(_skinAnimationEnabledKey) ??
          AppConfigState.initial.enableSkinAnimation,
      isMonochrome: prefs.getBool(_monochromeKey) ?? false,
      localeCode: _readLocaleCode(prefs.getString(_localeKey)),
      onlineAudioQualityPreference: AppOnlineAudioQuality.fromValue(
        prefs.getString(_onlineAudioQualityPreferenceKey),
      ),
      autoCheckUpdates: prefs.getBool(_autoCheckUpdatesKey) ?? true,
      playerBackgroundStyle: AppPlayerBackgroundStyle.fromValue(
        prefs.getString(_playerBackgroundStyleKey),
      ),
      lyricHighlightMode: lyricHighlightMode,
      lyricHighlightPreset: _readLyricHighlightPreset(prefs),
      lyricHighlightCustomColor: _readLyricHighlightCustomColor(prefs),
      clearLyricHighlightCustomColor:
          _readLyricHighlightCustomColor(prefs) == null,
      lyricFontPreset: AppLyricFontPreset.fromValue(
        prefs.getString(_lyricFontPresetKey),
      ),
      enableWordByWordLyric:
          prefs.getBool(_enableWordByWordLyricKey) ??
          AppConfigState.initial.enableWordByWordLyric,
      enableDesktopLyric: prefs.getBool(_enableDesktopLyricKey) ?? false,
      enableDesktopLyricLock:
          prefs.getBool(_enableDesktopLyricLockKey) ?? false,
      lastSelectedOnlineAudioQualityName:
          _readLastSelectedOnlineAudioQualityName(
            prefs.getString(_lastSelectedOnlineAudioQualityNameKey),
          ),
      authToken: authToken,
      clearToken: prefs.containsKey(_authTokenKey) && authToken == null,
      refreshToken: refreshToken,
      clearRefreshToken:
          prefs.containsKey(_refreshTokenKey) && refreshToken == null,
      tokenExpiresAt: tokenExpiresAt,
    );
  }

  Future<void> save(AppConfigState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, state.themeMode.name);
    await prefs.setString(_themeAccentKey, state.themeAccent.value);
    await prefs.setString(_skinIdKey, state.skinId);
    await prefs.setBool(_skinAnimationEnabledKey, state.enableSkinAnimation);
    await prefs.setBool(_monochromeKey, state.isMonochrome);
    await prefs.setString(_localeKey, state.localeCode);
    await prefs.setString(
      _onlineAudioQualityPreferenceKey,
      state.onlineAudioQualityPreference.value,
    );
    await prefs.setBool(_autoCheckUpdatesKey, state.autoCheckUpdates);
    await prefs.setString(
      _playerBackgroundStyleKey,
      state.playerBackgroundStyle.value,
    );
    await prefs.setString(
      _lyricHighlightModeKey,
      state.lyricHighlightMode.value,
    );
    await prefs.setString(
      _lyricHighlightPresetKey,
      state.lyricHighlightPreset.value,
    );
    final lyricHighlightCustomColor = state.lyricHighlightCustomColor;
    if (lyricHighlightCustomColor == null) {
      await prefs.remove(_lyricHighlightCustomColorKey);
    } else {
      await prefs.setString(
        _lyricHighlightCustomColorKey,
        lyricHighlightCustomColor.toString(),
      );
    }
    await prefs.setString(_lyricFontPresetKey, state.lyricFontPreset.value);
    await prefs.setBool(_enableWordByWordLyricKey, state.enableWordByWordLyric);
    await prefs.setBool(_enableDesktopLyricKey, state.enableDesktopLyric);
    await prefs.setBool(
      _enableDesktopLyricLockKey,
      state.enableDesktopLyricLock,
    );
    final lastSelected = state.lastSelectedOnlineAudioQualityName?.trim();
    if (lastSelected == null || lastSelected.isEmpty) {
      await prefs.remove(_lastSelectedOnlineAudioQualityNameKey);
    } else {
      await prefs.setString(
        _lastSelectedOnlineAudioQualityNameKey,
        lastSelected,
      );
    }
    final authToken = state.authToken?.trim() ?? '';
    if (authToken.isEmpty) {
      await prefs.remove(_authTokenKey);
    } else {
      await prefs.setString(_authTokenKey, authToken);
    }
    final refreshToken = state.refreshToken?.trim() ?? '';
    if (refreshToken.isEmpty) {
      await prefs.remove(_refreshTokenKey);
    } else {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
    final tokenExpiresAt = state.tokenExpiresAt;
    if (tokenExpiresAt == null) {
      await prefs.remove(_tokenExpiresAtKey);
    } else {
      await prefs.setInt(_tokenExpiresAtKey, tokenExpiresAt);
    }
  }

  String? _readLastSelectedOnlineAudioQualityName(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? _readAuthToken(String? value, {required bool hasStoredValue}) {
    if (!hasStoredValue) {
      return null;
    }
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  AppThemeMode _readThemeMode(String? value) {
    for (final item in AppThemeMode.values) {
      if (item.name == value) {
        return item;
      }
    }
    return AppConfigState.initial.themeMode;
  }

  String _readSkinId(String? value) {
    return AppSkinRegistry.builtInIds.contains(value)
        ? value!
        : AppSkinRegistry.classicId;
  }

  String _readLocaleCode(String? value) {
    if (value == 'system' || value == 'zh' || value == 'en') {
      return value!;
    }
    return AppConfigState.initial.localeCode;
  }

  AppLyricHighlightMode _readLyricHighlightMode(SharedPreferences prefs) {
    final stored = prefs.getString(_lyricHighlightModeKey);
    if (stored != null) {
      return AppLyricHighlightMode.fromValue(stored);
    }
    if (prefs.containsKey(_legacyLyricHighlightColorKey)) {
      return AppLyricHighlightMode.preset;
    }
    return AppConfigState.initial.lyricHighlightMode;
  }

  AppLyricHighlightColor _readLyricHighlightPreset(SharedPreferences prefs) {
    final stored = prefs.getString(_lyricHighlightPresetKey);
    if (stored != null) {
      return AppLyricHighlightColor.fromValue(stored);
    }
    return AppLyricHighlightColor.fromValue(
      prefs.getString(_legacyLyricHighlightColorKey),
    );
  }

  int? _readLyricHighlightCustomColor(SharedPreferences prefs) {
    final stored = prefs.getString(_lyricHighlightCustomColorKey)?.trim() ?? '';
    if (stored.isEmpty) {
      return null;
    }
    final colorValue = int.tryParse(stored);
    if (colorValue == null) {
      return null;
    }
    return Color(colorValue).toARGB32();
  }
}
