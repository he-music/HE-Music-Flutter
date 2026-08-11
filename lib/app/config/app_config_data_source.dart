import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import 'app_custom_skin_config.dart';
import 'app_config_state.dart';
import 'app_lyric_font_preset.dart';
import 'app_lyric_highlight_color.dart';
import 'app_lyric_highlight_mode.dart';
import 'app_online_audio_quality.dart';
import 'app_theme_accent.dart';
import 'app_theme_mode.dart';
import '../theme/player/app_player_style_registry.dart';
import '../theme/skin/app_skin_registry.dart';

const _themeModeKey = 'app_config.theme_mode';
const _themeAccentKey = 'app_config.theme_accent';
const _skinIdKey = 'app_config.skin_id';
const _customSkinKey = 'app_config.custom_skin';
const _skinAnimationEnabledKey = 'app_config.skin_animation_enabled';
const _showContentBackgroundKey = 'app_config.show_content_background';
const _monochromeKey = 'app_config.monochrome';
const _localeKey = 'app_config.locale';
const _legacyOnlineAudioQualityPreferenceKey =
    'app_config.online_audio_quality_preference';
const _wifiOnlineAudioQualityPreferenceKey =
    'app_config.wifi_online_audio_quality_preference';
const _cellularOnlineAudioQualityPreferenceKey =
    'app_config.cellular_online_audio_quality_preference';
const _lastSelectedOnlineAudioQualityNameKey =
    'app_config.last_selected_online_audio_quality';
const _autoCheckUpdatesKey = 'app_config.auto_check_updates';
const _githubDownloadAccelerationEnabledKey =
    'app_config.github_download_acceleration_enabled';
const _githubDownloadProxyAutoUpdateEnabledKey =
    'app_config.github_download_proxy_auto_update_enabled';
const _githubDownloadProxyIdKey = 'app_config.github_download_proxy_id';
const _playerStyleIdKey = 'app_config.player_style_id';
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
    await _migrateAudioQualityPreferences(prefs);
    final lyricHighlightMode = _readLyricHighlightMode(prefs);
    final storedCustomSkin = prefs.getString(_customSkinKey);
    final customSkin = AppCustomSkinConfig.tryDecode(storedCustomSkin);
    if (prefs.containsKey(_customSkinKey) && customSkin == null) {
      await prefs.remove(_customSkinKey);
    }
    final skinId = _readSkinId(
      prefs.getString(_skinIdKey),
      hasCustomSkin: customSkin != null,
    );
    final playerStyleId = AppPlayerStyleRegistry.instance.normalizeId(
      prefs.getString(_playerStyleIdKey),
    );
    if (prefs.containsKey(_skinIdKey) &&
        prefs.getString(_skinIdKey) != skinId) {
      await prefs.setString(_skinIdKey, skinId);
    }
    if (prefs.getString(_playerStyleIdKey) != playerStyleId) {
      await prefs.setString(_playerStyleIdKey, playerStyleId);
    }
    return AppConfigState.initial.copyWith(
      themeMode: _readThemeMode(prefs.getString(_themeModeKey)),
      themeAccent: AppThemeAccent.fromValue(prefs.getString(_themeAccentKey)),
      skinId: skinId,
      customSkinConfig: customSkin,
      enableSkinAnimation:
          prefs.getBool(_skinAnimationEnabledKey) ??
          AppConfigState.initial.enableSkinAnimation,
      showContentBackground:
          prefs.getBool(_showContentBackgroundKey) ??
          AppConfigState.initial.showContentBackground,
      isMonochrome: prefs.getBool(_monochromeKey) ?? false,
      localeCode: _readLocaleCode(prefs.getString(_localeKey)),
      wifiOnlineAudioQualityPreference: _readNetworkAudioQuality(
        prefs,
        _wifiOnlineAudioQualityPreferenceKey,
        fallback: AppConfigState.initial.wifiOnlineAudioQualityPreference,
      ),
      cellularOnlineAudioQualityPreference: _readNetworkAudioQuality(
        prefs,
        _cellularOnlineAudioQualityPreferenceKey,
        fallback: AppConfigState.initial.cellularOnlineAudioQualityPreference,
      ),
      autoCheckUpdates: prefs.getBool(_autoCheckUpdatesKey) ?? true,
      githubDownloadAccelerationEnabled:
          prefs.getBool(_githubDownloadAccelerationEnabledKey) ?? false,
      githubDownloadProxyAutoUpdateEnabled:
          prefs.getBool(_githubDownloadProxyAutoUpdateEnabledKey) ?? true,
      playerStyleId: playerStyleId,
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
      githubDownloadProxyId: _readNullableString(
        prefs.getString(_githubDownloadProxyIdKey),
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
    final customSkin = state.customSkinConfig;
    if (customSkin == null) {
      await prefs.remove(_customSkinKey);
    } else {
      await prefs.setString(_customSkinKey, customSkin.encode());
    }
    await prefs.setBool(_skinAnimationEnabledKey, state.enableSkinAnimation);
    await prefs.setBool(_showContentBackgroundKey, state.showContentBackground);
    await prefs.setBool(_monochromeKey, state.isMonochrome);
    await prefs.setString(_localeKey, state.localeCode);
    await prefs.setString(
      _wifiOnlineAudioQualityPreferenceKey,
      state.wifiOnlineAudioQualityPreference.value,
    );
    await prefs.setString(
      _cellularOnlineAudioQualityPreferenceKey,
      state.cellularOnlineAudioQualityPreference.value,
    );
    await prefs.remove(_legacyOnlineAudioQualityPreferenceKey);
    await prefs.setBool(_autoCheckUpdatesKey, state.autoCheckUpdates);
    await prefs.setBool(
      _githubDownloadAccelerationEnabledKey,
      state.githubDownloadAccelerationEnabled,
    );
    await prefs.setBool(
      _githubDownloadProxyAutoUpdateEnabledKey,
      state.githubDownloadProxyAutoUpdateEnabled,
    );
    await prefs.setString(
      _playerStyleIdKey,
      AppPlayerStyleRegistry.instance.normalizeId(state.playerStyleId),
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
    final githubDownloadProxyId = state.githubDownloadProxyId?.trim() ?? '';
    if (githubDownloadProxyId.isEmpty) {
      await prefs.remove(_githubDownloadProxyIdKey);
    } else {
      await prefs.setString(_githubDownloadProxyIdKey, githubDownloadProxyId);
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

  /// refresh 只更新 token 三元组，避免用旧配置快照覆盖其他并发设置。
  Future<void> saveTokens(
    String accessToken,
    String refreshToken,
    int expiresAt,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, accessToken.trim());
    await prefs.setString(_refreshTokenKey, refreshToken.trim());
    await prefs.setInt(_tokenExpiresAtKey, expiresAt);
  }

  /// 自定义皮肤配置与当前皮肤 ID 使用可回滚的独立提交边界。
  Future<void> replaceCustomSkin(AppCustomSkinConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final previousCustom = prefs.getString(_customSkinKey);
    final previousSkin = prefs.getString(_skinIdKey);
    try {
      if (!await prefs.setString(_customSkinKey, config.encode())) {
        throw StateError('保存自定义皮肤配置失败');
      }
      if (!await prefs.setString(_skinIdKey, AppSkinRegistry.customImageId)) {
        throw StateError('应用自定义皮肤失败');
      }
    } catch (error) {
      final restoredCustom = previousCustom == null
          ? await prefs.remove(_customSkinKey)
          : await prefs.setString(_customSkinKey, previousCustom);
      final restoredSkin = previousSkin == null
          ? await prefs.remove(_skinIdKey)
          : await prefs.setString(_skinIdKey, previousSkin);
      if (!restoredCustom || !restoredSkin) {
        throw StateError('自定义皮肤保存失败且旧配置恢复失败');
      }
      throw StateError('自定义皮肤保存失败: $error');
    }
  }

  /// 返回删除后应继续使用的皮肤 ID。
  Future<String> deleteCustomSkin() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(_skinIdKey);
    final normalized = AppSkinRegistry.builtInIds.contains(current)
        ? current!
        : AppSkinRegistry.classicId;
    final fallbackToClassic = current == AppSkinRegistry.customImageId;
    if (fallbackToClassic &&
        !await prefs.setString(_skinIdKey, AppSkinRegistry.classicId)) {
      throw StateError('回退经典皮肤失败');
    }
    if (!await prefs.remove(_customSkinKey)) {
      if (fallbackToClassic &&
          !await prefs.setString(_skinIdKey, AppSkinRegistry.customImageId)) {
        throw StateError('删除自定义皮肤失败且旧皮肤恢复失败');
      }
      throw StateError('删除自定义皮肤配置失败');
    }
    return fallbackToClassic ? AppSkinRegistry.classicId : normalized;
  }

  Future<void> clearInvalidCustomSkin({required bool fallbackToClassic}) async {
    final prefs = await SharedPreferences.getInstance();
    if (fallbackToClassic &&
        !await prefs.setString(_skinIdKey, AppSkinRegistry.classicId)) {
      throw StateError('回退经典皮肤失败');
    }
    if (!await prefs.remove(_customSkinKey)) {
      throw StateError('清理损坏的自定义皮肤配置失败');
    }
  }

  String? _readLastSelectedOnlineAudioQualityName(String? value) {
    return _readNullableString(value);
  }

  AppOnlineAudioQuality _readNetworkAudioQuality(
    SharedPreferences prefs,
    String key, {
    required AppOnlineAudioQuality fallback,
  }) {
    final value = prefs.getString(key);
    if (value != null) {
      return AppOnlineAudioQuality.fromValue(value);
    }
    final legacyValue = prefs.getString(_legacyOnlineAudioQualityPreferenceKey);
    return legacyValue == null
        ? fallback
        : AppOnlineAudioQuality.fromValue(legacyValue);
  }

  Future<void> _migrateAudioQualityPreferences(SharedPreferences prefs) async {
    final legacy = prefs.getString(_legacyOnlineAudioQualityPreferenceKey);
    if (legacy == null) {
      return;
    }
    final normalized = AppOnlineAudioQuality.fromValue(legacy).value;
    if (!prefs.containsKey(_wifiOnlineAudioQualityPreferenceKey)) {
      await prefs.setString(_wifiOnlineAudioQualityPreferenceKey, normalized);
    }
    if (!prefs.containsKey(_cellularOnlineAudioQualityPreferenceKey)) {
      await prefs.setString(
        _cellularOnlineAudioQualityPreferenceKey,
        normalized,
      );
    }
    await prefs.remove(_legacyOnlineAudioQualityPreferenceKey);
  }

  String? _readNullableString(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
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

  String _readSkinId(String? value, {required bool hasCustomSkin}) {
    if (AppSkinRegistry.builtInIds.contains(value)) {
      return value!;
    }
    if (hasCustomSkin && value == AppSkinRegistry.customImageId) {
      return value!;
    }
    return AppSkinRegistry.classicId;
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
