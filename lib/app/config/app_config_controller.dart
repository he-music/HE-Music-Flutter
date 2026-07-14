import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/token_refresh_interceptor.dart';
import 'app_config_data_source.dart';
import 'app_config_state.dart';
import 'app_lyric_font_preset.dart';
import 'app_lyric_highlight_color.dart';
import 'app_lyric_highlight_mode.dart';
import 'app_online_audio_quality.dart';
import 'app_player_background_style.dart';
import 'app_theme_accent.dart';
import 'app_theme_mode.dart';

class AppConfigController extends Notifier<AppConfigState> {
  late final Future<void> _hydrationFuture;

  @override
  AppConfigState build() {
    _hydrationFuture = _hydrate();
    return AppConfigState.initial;
  }

  /// 等待本地配置和 token 完成一次性水合。
  Future<void> waitUntilHydrated() => _hydrationFuture;

  void cycleThemeMode() {
    final next = switch (state.themeMode) {
      AppThemeMode.system => AppThemeMode.light,
      AppThemeMode.light => AppThemeMode.dark,
      AppThemeMode.dark => AppThemeMode.system,
    };
    _update(state.copyWith(themeMode: next));
  }

  void setThemeMode(AppThemeMode mode) {
    _update(state.copyWith(themeMode: mode));
  }

  void setThemeAccent(AppThemeAccent accent) {
    _update(state.copyWith(themeAccent: accent));
  }

  void toggleMonochrome() {
    _update(state.copyWith(isMonochrome: !state.isMonochrome));
  }

  void setLocaleCode(String localeCode) {
    if (localeCode != 'system' && localeCode != 'zh' && localeCode != 'en') {
      return;
    }
    _update(state.copyWith(localeCode: localeCode));
  }

  void setOnlineAudioQualityPreference(AppOnlineAudioQuality quality) {
    _update(state.copyWith(onlineAudioQualityPreference: quality));
  }

  void setAutoCheckUpdates(bool value) {
    _update(state.copyWith(autoCheckUpdates: value));
  }

  void setPlayerBackgroundStyle(AppPlayerBackgroundStyle style) {
    _update(state.copyWith(playerBackgroundStyle: style));
  }

  void setLyricHighlightMode(AppLyricHighlightMode mode) {
    _update(state.copyWith(lyricHighlightMode: mode));
  }

  void setLyricHighlightPreset(AppLyricHighlightColor color) {
    _update(
      state.copyWith(
        lyricHighlightMode: AppLyricHighlightMode.preset,
        lyricHighlightPreset: color,
      ),
    );
  }

  void setLyricHighlightCustomColor(int colorValue) {
    _update(
      state.copyWith(
        lyricHighlightMode: AppLyricHighlightMode.custom,
        lyricHighlightCustomColor: colorValue,
      ),
    );
  }

  void setLyricFontPreset(AppLyricFontPreset preset) {
    _update(state.copyWith(lyricFontPreset: preset));
  }

  void setEnableWordByWordLyric(bool value) {
    _update(state.copyWith(enableWordByWordLyric: value));
  }

  void setEnableDesktopLyric(bool value) {
    _update(state.copyWith(enableDesktopLyric: value));
  }

  void setEnableDesktopLyricLock(bool value) {
    _update(state.copyWith(enableDesktopLyricLock: value));
  }

  void setLastSelectedOnlineAudioQualityName(String qualityName) {
    final normalized = qualityName.trim();
    if (normalized.isEmpty) {
      return;
    }
    _update(state.copyWith(lastSelectedOnlineAudioQualityName: normalized));
  }

  void setAuthToken(String token) {
    _update(state.copyWith(authToken: token.trim(), clearRefreshToken: true));
  }

  /// 一次性设置 access_token、refresh_token 和过期时间。
  void setTokens(String accessToken, String refreshToken, int expiresAt) {
    _update(
      state.copyWith(
        authToken: accessToken.trim(),
        refreshToken: refreshToken.trim(),
        tokenExpiresAt: expiresAt,
      ),
    );
  }

  void clearAuthToken() {
    _update(state.copyWith(clearToken: true, clearRefreshToken: true));
  }

  /// 仅持久化 token 三元组到 SharedPreferences，不更新 Riverpod state。
  /// 用于 Token 刷新场景：TokenHolder 已经持有最新值，
  /// 此处仅确保持久化，避免触发 apiDioProvider 重建。
  void persistTokens(String accessToken, String refreshToken, int expiresAt) {
    final snapshot = state.copyWith(
      authToken: accessToken.trim(),
      refreshToken: refreshToken.trim(),
      tokenExpiresAt: expiresAt,
    );
    _persist(snapshot);
  }

  void _update(AppConfigState next, {bool persist = true}) {
    state = next;
    if (!persist) {
      return;
    }
    _persist(next);
  }

  Future<void> _hydrate() async {
    final loaded = await ref.read(appConfigDataSourceProvider).load();
    // 刷新拦截器可能已更新全局 token，水合时必须优先保留实时值。
    final accessToken = globalTokenHolder.accessToken ?? loaded.authToken;
    final refreshToken = globalTokenHolder.refreshToken ?? loaded.refreshToken;
    state = state.copyWith(
      themeMode: loaded.themeMode,
      themeAccent: loaded.themeAccent,
      isMonochrome: loaded.isMonochrome,
      localeCode: loaded.localeCode,
      onlineAudioQualityPreference: loaded.onlineAudioQualityPreference,
      autoCheckUpdates: loaded.autoCheckUpdates,
      playerBackgroundStyle: loaded.playerBackgroundStyle,
      lyricHighlightMode: loaded.lyricHighlightMode,
      lyricHighlightPreset: loaded.lyricHighlightPreset,
      lyricHighlightCustomColor: loaded.lyricHighlightCustomColor,
      clearLyricHighlightCustomColor: loaded.lyricHighlightCustomColor == null,
      lyricFontPreset: loaded.lyricFontPreset,
      enableWordByWordLyric: loaded.enableWordByWordLyric,
      enableDesktopLyric: loaded.enableDesktopLyric,
      enableDesktopLyricLock: loaded.enableDesktopLyricLock,
      lastSelectedOnlineAudioQualityName:
          loaded.lastSelectedOnlineAudioQualityName,
      authToken: accessToken,
      clearToken: accessToken == null,
      refreshToken: refreshToken,
      clearRefreshToken: refreshToken == null,
      tokenExpiresAt: loaded.tokenExpiresAt,
    );
  }

  void _persist(AppConfigState value) {
    Future.microtask(() async {
      await ref.read(appConfigDataSourceProvider).save(value);
    });
  }
}

final appConfigDataSourceProvider = Provider<AppConfigDataSource>((ref) {
  return const AppConfigDataSource();
});

final appConfigProvider = NotifierProvider<AppConfigController, AppConfigState>(
  AppConfigController.new,
);
