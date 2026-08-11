import 'app_environment.dart';
import 'app_custom_skin_config.dart';
import 'app_lyric_font_preset.dart';
import 'app_lyric_highlight_color.dart';
import 'app_lyric_highlight_mode.dart';
import 'app_online_audio_quality.dart';
import 'app_theme_accent.dart';
import 'app_theme_mode.dart';
import '../theme/player/app_player_style_registry.dart';

class AppConfigState {
  const AppConfigState({
    required this.apiBaseUrl,
    required this.themeMode,
    required this.themeAccent,
    required this.skinId,
    this.customSkinConfig,
    required this.enableSkinAnimation,
    required this.showContentBackground,
    required this.isMonochrome,
    required this.localeCode,
    required this.wifiOnlineAudioQualityPreference,
    required this.cellularOnlineAudioQualityPreference,
    required this.autoCheckUpdates,
    required this.githubDownloadAccelerationEnabled,
    required this.githubDownloadProxyAutoUpdateEnabled,
    required this.playerStyleId,
    required this.lyricHighlightMode,
    required this.lyricHighlightPreset,
    this.lyricHighlightCustomColor,
    required this.lyricFontPreset,
    required this.enableWordByWordLyric,
    required this.enableDesktopLyric,
    required this.enableDesktopLyricLock,
    this.lastSelectedOnlineAudioQualityName,
    this.githubDownloadProxyId,
    this.authToken,
    this.refreshToken,
    this.tokenExpiresAt,
  });

  final String apiBaseUrl;
  final AppThemeMode themeMode;
  final AppThemeAccent themeAccent;
  final String skinId;
  final AppCustomSkinConfig? customSkinConfig;
  final bool enableSkinAnimation;
  final bool showContentBackground;
  final bool isMonochrome;
  final String localeCode;
  final AppOnlineAudioQuality wifiOnlineAudioQualityPreference;
  final AppOnlineAudioQuality cellularOnlineAudioQualityPreference;
  final bool autoCheckUpdates;
  final bool githubDownloadAccelerationEnabled;
  final bool githubDownloadProxyAutoUpdateEnabled;
  final String playerStyleId;
  final AppLyricHighlightMode lyricHighlightMode;
  final AppLyricHighlightColor lyricHighlightPreset;
  final int? lyricHighlightCustomColor;
  final AppLyricFontPreset lyricFontPreset;
  final bool enableWordByWordLyric;
  final bool enableDesktopLyric;
  final bool enableDesktopLyricLock;
  final String? lastSelectedOnlineAudioQualityName;
  final String? githubDownloadProxyId;
  final String? authToken;
  final String? refreshToken;
  final int? tokenExpiresAt;

  AppConfigState copyWith({
    String? apiBaseUrl,
    AppThemeMode? themeMode,
    AppThemeAccent? themeAccent,
    String? skinId,
    AppCustomSkinConfig? customSkinConfig,
    bool clearCustomSkinConfig = false,
    bool? enableSkinAnimation,
    bool? showContentBackground,
    bool? isMonochrome,
    String? localeCode,
    AppOnlineAudioQuality? wifiOnlineAudioQualityPreference,
    AppOnlineAudioQuality? cellularOnlineAudioQualityPreference,
    bool? autoCheckUpdates,
    bool? githubDownloadAccelerationEnabled,
    bool? githubDownloadProxyAutoUpdateEnabled,
    String? playerStyleId,
    AppLyricHighlightMode? lyricHighlightMode,
    AppLyricHighlightColor? lyricHighlightPreset,
    int? lyricHighlightCustomColor,
    bool clearLyricHighlightCustomColor = false,
    AppLyricFontPreset? lyricFontPreset,
    bool? enableWordByWordLyric,
    bool? enableDesktopLyric,
    bool? enableDesktopLyricLock,
    String? lastSelectedOnlineAudioQualityName,
    bool clearLastSelectedOnlineAudioQuality = false,
    String? githubDownloadProxyId,
    bool clearGitHubDownloadProxyId = false,
    String? authToken,
    bool clearToken = false,
    String? refreshToken,
    int? tokenExpiresAt,
    bool clearRefreshToken = false,
  }) {
    return AppConfigState(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      themeMode: themeMode ?? this.themeMode,
      themeAccent: themeAccent ?? this.themeAccent,
      skinId: skinId ?? this.skinId,
      customSkinConfig: clearCustomSkinConfig
          ? null
          : customSkinConfig ?? this.customSkinConfig,
      enableSkinAnimation: enableSkinAnimation ?? this.enableSkinAnimation,
      showContentBackground:
          showContentBackground ?? this.showContentBackground,
      isMonochrome: isMonochrome ?? this.isMonochrome,
      localeCode: localeCode ?? this.localeCode,
      wifiOnlineAudioQualityPreference:
          wifiOnlineAudioQualityPreference ??
          this.wifiOnlineAudioQualityPreference,
      cellularOnlineAudioQualityPreference:
          cellularOnlineAudioQualityPreference ??
          this.cellularOnlineAudioQualityPreference,
      autoCheckUpdates: autoCheckUpdates ?? this.autoCheckUpdates,
      githubDownloadAccelerationEnabled:
          githubDownloadAccelerationEnabled ??
          this.githubDownloadAccelerationEnabled,
      githubDownloadProxyAutoUpdateEnabled:
          githubDownloadProxyAutoUpdateEnabled ??
          this.githubDownloadProxyAutoUpdateEnabled,
      playerStyleId: playerStyleId ?? this.playerStyleId,
      lyricHighlightMode: lyricHighlightMode ?? this.lyricHighlightMode,
      lyricHighlightPreset: lyricHighlightPreset ?? this.lyricHighlightPreset,
      lyricHighlightCustomColor: clearLyricHighlightCustomColor
          ? null
          : lyricHighlightCustomColor ?? this.lyricHighlightCustomColor,
      lyricFontPreset: lyricFontPreset ?? this.lyricFontPreset,
      enableWordByWordLyric:
          enableWordByWordLyric ?? this.enableWordByWordLyric,
      enableDesktopLyric: enableDesktopLyric ?? this.enableDesktopLyric,
      enableDesktopLyricLock:
          enableDesktopLyricLock ?? this.enableDesktopLyricLock,
      lastSelectedOnlineAudioQualityName: clearLastSelectedOnlineAudioQuality
          ? null
          : lastSelectedOnlineAudioQualityName ??
                this.lastSelectedOnlineAudioQualityName,
      githubDownloadProxyId: clearGitHubDownloadProxyId
          ? null
          : githubDownloadProxyId ?? this.githubDownloadProxyId,
      authToken: clearToken ? null : authToken ?? this.authToken,
      refreshToken: clearToken || clearRefreshToken
          ? null
          : refreshToken ?? this.refreshToken,
      tokenExpiresAt: clearToken || clearRefreshToken
          ? null
          : tokenExpiresAt ?? this.tokenExpiresAt,
    );
  }

  static final initial = AppConfigState(
    themeMode: AppThemeMode.system,
    themeAccent: AppThemeAccent.forest,
    skinId: 'classic',
    enableSkinAnimation: true,
    showContentBackground: false,
    isMonochrome: false,
    localeCode: 'zh',
    wifiOnlineAudioQualityPreference: AppOnlineAudioQuality.auto,
    cellularOnlineAudioQualityPreference: AppOnlineAudioQuality.mp3320,
    autoCheckUpdates: true,
    githubDownloadAccelerationEnabled: false,
    githubDownloadProxyAutoUpdateEnabled: true,
    playerStyleId: AppPlayerStyleRegistry.classicId,
    lyricHighlightMode: AppLyricHighlightMode.preset,
    lyricHighlightPreset: AppLyricHighlightColor.sky,
    lyricFontPreset: AppLyricFontPreset.medium,
    enableWordByWordLyric: true,
    enableDesktopLyric: false,
    enableDesktopLyricLock: false,
    apiBaseUrl: AppEnvironment.apiBaseUrl,
  );
}
