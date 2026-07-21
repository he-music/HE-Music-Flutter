import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/token_refresh_interceptor.dart';
import 'app_config_data_source.dart';
import 'app_config_state.dart';
import 'app_lyric_font_preset.dart';
import 'app_lyric_highlight_color.dart';
import 'app_lyric_highlight_mode.dart';
import 'app_online_audio_quality.dart';
import 'app_theme_accent.dart';
import 'app_theme_mode.dart';
import '../theme/player/app_player_style_registry.dart';
import '../theme/skin/app_skin_registry.dart';

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

  void setSkinId(String skinId) {
    final normalized = AppSkinRegistry.builtInIds.contains(skinId)
        ? skinId
        : AppSkinRegistry.classicId;
    _update(state.copyWith(skinId: normalized));
  }

  void setEnableSkinAnimation(bool value) {
    _update(state.copyWith(enableSkinAnimation: value));
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

  void setPlayerStyleId(String styleId) {
    final normalized = AppPlayerStyleRegistry.instance.normalizeId(styleId);
    _update(state.copyWith(playerStyleId: normalized));
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
    final accessToken = token.trim();
    globalTokenHolder
      ..accessToken = accessToken
      ..refreshToken = null
      ..expiresAt = null;
    _update(state.copyWith(authToken: accessToken, clearRefreshToken: true));
  }

  /// 一次性设置 access_token、refresh_token 和过期时间。
  void setTokens(String accessToken, String refreshToken, int expiresAt) {
    final normalizedAccess = accessToken.trim();
    final normalizedRefresh = refreshToken.trim();
    globalTokenHolder
      ..accessToken = normalizedAccess
      ..refreshToken = normalizedRefresh
      ..expiresAt = expiresAt;
    _update(
      state.copyWith(
        authToken: normalizedAccess,
        refreshToken: normalizedRefresh,
        tokenExpiresAt: expiresAt,
      ),
    );
  }

  void clearAuthToken() {
    globalTokenHolder
      ..accessToken = null
      ..refreshToken = null
      ..expiresAt = null;
    _update(state.copyWith(clearToken: true, clearRefreshToken: true));
  }

  /// refresh 后同步内存状态并定向持久化，不触发 apiDioProvider 重建。
  Future<void> persistTokens(
    String accessToken,
    String refreshToken,
    int expiresAt,
  ) {
    final normalizedAccess = accessToken.trim();
    final normalizedRefresh = refreshToken.trim();
    globalTokenHolder
      ..accessToken = normalizedAccess
      ..refreshToken = normalizedRefresh
      ..expiresAt = expiresAt;
    state = state.copyWith(
      authToken: normalizedAccess,
      refreshToken: normalizedRefresh,
      tokenExpiresAt: expiresAt,
    );
    return ref
        .read(appConfigDataSourceProvider)
        .saveTokens(normalizedAccess, normalizedRefresh, expiresAt);
  }

  void _update(AppConfigState next, {bool persist = true}) {
    final accessToken = globalTokenHolder.accessToken;
    final refreshToken = globalTokenHolder.refreshToken;
    final effective = next.copyWith(
      authToken: accessToken,
      clearToken: accessToken == null,
      refreshToken: refreshToken,
      tokenExpiresAt: globalTokenHolder.expiresAt,
      clearRefreshToken: refreshToken == null,
    );
    state = effective;
    if (!persist) {
      return;
    }
    _persist(effective);
  }

  Future<void> _hydrate() async {
    final loaded = await ref.read(appConfigDataSourceProvider).load();
    // 刷新拦截器可能已更新全局 token，水合时必须优先保留实时值。
    globalTokenHolder.accessToken ??= loaded.authToken;
    globalTokenHolder.refreshToken ??= loaded.refreshToken;
    globalTokenHolder.expiresAt ??= loaded.tokenExpiresAt;
    final accessToken = globalTokenHolder.accessToken ?? loaded.authToken;
    final refreshToken = globalTokenHolder.refreshToken ?? loaded.refreshToken;
    state = state.copyWith(
      themeMode: loaded.themeMode,
      themeAccent: loaded.themeAccent,
      skinId: loaded.skinId,
      enableSkinAnimation: loaded.enableSkinAnimation,
      isMonochrome: loaded.isMonochrome,
      localeCode: loaded.localeCode,
      onlineAudioQualityPreference: loaded.onlineAudioQualityPreference,
      autoCheckUpdates: loaded.autoCheckUpdates,
      playerStyleId: loaded.playerStyleId,
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
      tokenExpiresAt: globalTokenHolder.expiresAt ?? loaded.tokenExpiresAt,
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
