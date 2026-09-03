import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/token_refresh_interceptor.dart';
import '../theme/skin/app_custom_skin_store.dart';
import 'app_config_data_source.dart';
import 'app_config_state.dart';
import 'app_custom_skin_config.dart';
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
  Future<void> _persistenceQueue = Future<void>.value();

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
    final normalized = AppSkinRegistry.withCustom(
      state.themeAccent,
      state.customSkinConfig,
    ).normalizeId(skinId);
    _update(state.copyWith(skinId: normalized));
  }

  Future<void> applyCustomSkin(AppCustomSkinConfig config) async {
    final store = ref.read(appCustomSkinStoreProvider);
    if (!await store.validateConfig(config)) {
      throw StateError('自定义皮肤资源不可用');
    }
    await _enqueuePersistence(() async {
      await ref.read(appConfigDataSourceProvider).replaceCustomSkin(config);
      if (!ref.mounted) {
        return;
      }
      state = _withLiveTokens(
        state.copyWith(
          skinId: AppSkinRegistry.customImageId,
          customSkinConfig: config,
        ),
      );
    });
    if (!ref.mounted) {
      return;
    }
    unawaited(store.cleanupOrphans(config).catchError((_) {}));
  }

  Future<void> deleteCustomSkin() async {
    await _enqueuePersistence(() async {
      final nextSkinId = await ref
          .read(appConfigDataSourceProvider)
          .deleteCustomSkin();
      if (!ref.mounted) {
        return;
      }
      state = _withLiveTokens(
        state.copyWith(skinId: nextSkinId, clearCustomSkinConfig: true),
      );
    });
    if (!ref.mounted) {
      return;
    }
    await ref.read(appCustomSkinStoreProvider).deleteAll();
  }

  void setEnableSkinAnimation(bool value) {
    _update(state.copyWith(enableSkinAnimation: value));
  }

  void setShowContentBackground(bool value) {
    _update(state.copyWith(showContentBackground: value));
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

  void setWifiOnlineAudioQualityPreference(AppOnlineAudioQuality quality) {
    _update(state.copyWith(wifiOnlineAudioQualityPreference: quality));
  }

  void setCellularOnlineAudioQualityPreference(AppOnlineAudioQuality quality) {
    _update(state.copyWith(cellularOnlineAudioQualityPreference: quality));
  }

  void setAutoCheckUpdates(bool value) {
    _update(state.copyWith(autoCheckUpdates: value));
  }

  void setGitHubDownloadAccelerationEnabled(bool value) {
    _update(state.copyWith(githubDownloadAccelerationEnabled: value));
  }

  void setGitHubDownloadProxyAutoUpdateEnabled(bool value) {
    _update(state.copyWith(githubDownloadProxyAutoUpdateEnabled: value));
  }

  void setGitHubDownloadProxyId(String? proxyId) {
    final normalized = proxyId?.trim() ?? '';
    _update(
      state.copyWith(
        githubDownloadProxyId: normalized.isEmpty ? null : normalized,
        clearGitHubDownloadProxyId: normalized.isEmpty,
      ),
    );
  }

  void setPlayerStageId(String stageId) {
    final normalized = AppPlayerStageRegistry.instance.normalizeId(stageId);
    _update(state.copyWith(playerStageId: normalized));
  }

  void setPlayerBackdropId(String backdropId) {
    final normalized =
        AppPlayerBackdropRegistry.instance.normalizeId(backdropId);
    _update(state.copyWith(playerBackdropId: normalized));
  }

  void setPlayerLyricsId(String lyricsId) {
    final normalized = AppPlayerLyricsRegistry.instance.normalizeId(lyricsId);
    _update(state.copyWith(playerLyricsId: normalized));
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
    final effective = _withLiveTokens(next);
    state = effective;
    if (!persist) {
      return;
    }
    _persist();
  }

  Future<void> _hydrate() async {
    final loaded = await ref.read(appConfigDataSourceProvider).load();
    var customSkin = loaded.customSkinConfig;
    var skinId = loaded.skinId;
    final store = ref.read(appCustomSkinStoreProvider);
    if (customSkin != null && !await store.validateConfig(customSkin)) {
      final fallbackToClassic = skinId == AppSkinRegistry.customImageId;
      try {
        await ref
            .read(appConfigDataSourceProvider)
            .clearInvalidCustomSkin(fallbackToClassic: fallbackToClassic);
      } catch (_) {
        // 损坏配置不能阻断启动，内存状态仍回退到可用皮肤。
      }
      customSkin = null;
      if (fallbackToClassic) {
        skinId = AppSkinRegistry.classicId;
      }
    }
    if (!ref.mounted) {
      return;
    }
    // 刷新拦截器可能已更新全局 token，水合时必须优先保留实时值。
    globalTokenHolder.accessToken ??= loaded.authToken;
    globalTokenHolder.refreshToken ??= loaded.refreshToken;
    globalTokenHolder.expiresAt ??= loaded.tokenExpiresAt;
    final accessToken = globalTokenHolder.accessToken ?? loaded.authToken;
    final refreshToken = globalTokenHolder.refreshToken ?? loaded.refreshToken;
    state = state.copyWith(
      themeMode: loaded.themeMode,
      themeAccent: loaded.themeAccent,
      skinId: skinId,
      customSkinConfig: customSkin,
      clearCustomSkinConfig: customSkin == null,
      enableSkinAnimation: loaded.enableSkinAnimation,
      showContentBackground: loaded.showContentBackground,
      isMonochrome: loaded.isMonochrome,
      localeCode: loaded.localeCode,
      wifiOnlineAudioQualityPreference: loaded.wifiOnlineAudioQualityPreference,
      cellularOnlineAudioQualityPreference:
          loaded.cellularOnlineAudioQualityPreference,
      autoCheckUpdates: loaded.autoCheckUpdates,
      githubDownloadAccelerationEnabled:
          loaded.githubDownloadAccelerationEnabled,
      githubDownloadProxyAutoUpdateEnabled:
          loaded.githubDownloadProxyAutoUpdateEnabled,
      playerStageId: loaded.playerStageId,
      playerBackdropId: loaded.playerBackdropId,
      playerLyricsId: loaded.playerLyricsId,
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
      githubDownloadProxyId: loaded.githubDownloadProxyId,
      clearGitHubDownloadProxyId: loaded.githubDownloadProxyId == null,
      authToken: accessToken,
      clearToken: accessToken == null,
      refreshToken: refreshToken,
      clearRefreshToken: refreshToken == null,
      tokenExpiresAt: globalTokenHolder.expiresAt ?? loaded.tokenExpiresAt,
    );
    try {
      await store.cleanupOrphans(customSkin);
    } catch (_) {
      // 孤儿资源留待下次启动重试，不影响配置水合。
    }
  }

  AppConfigState _withLiveTokens(AppConfigState next) {
    final accessToken = globalTokenHolder.accessToken;
    final refreshToken = globalTokenHolder.refreshToken;
    return next.copyWith(
      authToken: accessToken,
      clearToken: accessToken == null,
      refreshToken: refreshToken,
      tokenExpiresAt: globalTokenHolder.expiresAt,
      clearRefreshToken: refreshToken == null,
    );
  }

  Future<T> _enqueuePersistence<T>(Future<T> Function() operation) {
    final result = _persistenceQueue.then((_) => operation());
    _persistenceQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  void _persist() {
    unawaited(
      _enqueuePersistence(() async {
        if (!ref.mounted) {
          return;
        }
        await ref
            .read(appConfigDataSourceProvider)
            .save(_withLiveTokens(state));
      }).catchError((_) {}),
    );
  }
}

final appConfigDataSourceProvider = Provider<AppConfigDataSource>((ref) {
  return const AppConfigDataSource();
});

final appCustomSkinStoreProvider = Provider<AppCustomSkinStore>((ref) {
  return AppCustomSkinStore();
});

final appConfigProvider = NotifierProvider<AppConfigController, AppConfigState>(
  AppConfigController.new,
);
