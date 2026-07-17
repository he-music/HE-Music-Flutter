import 'app_environment.dart';
import 'app_lyric_font_preset.dart';
import 'app_lyric_highlight_color.dart';
import 'app_lyric_highlight_mode.dart';
import 'app_online_audio_quality.dart';
import 'app_player_background_style.dart';
import 'app_theme_accent.dart';
import 'app_theme_mode.dart';

class AppConfigState {
  const AppConfigState({
    required this.apiBaseUrl,
    required this.themeMode,
    required this.themeAccent,
    required this.skinId,
    required this.enableSkinAnimation,
    required this.isMonochrome,
    required this.localeCode,
    required this.onlineAudioQualityPreference,
    required this.autoCheckUpdates,
    required this.playerBackgroundStyle,
    required this.lyricHighlightMode,
    required this.lyricHighlightPreset,
    this.lyricHighlightCustomColor,
    required this.lyricFontPreset,
    required this.enableWordByWordLyric,
    required this.enableDesktopLyric,
    required this.enableDesktopLyricLock,
    this.lastSelectedOnlineAudioQualityName,
    this.authToken,
    this.refreshToken,
    this.tokenExpiresAt,
  });

  final String apiBaseUrl;
  final AppThemeMode themeMode;
  final AppThemeAccent themeAccent;
  final String skinId;
  final bool enableSkinAnimation;
  final bool isMonochrome;
  final String localeCode;
  final AppOnlineAudioQuality onlineAudioQualityPreference;
  final bool autoCheckUpdates;
  final AppPlayerBackgroundStyle playerBackgroundStyle;
  final AppLyricHighlightMode lyricHighlightMode;
  final AppLyricHighlightColor lyricHighlightPreset;
  final int? lyricHighlightCustomColor;
  final AppLyricFontPreset lyricFontPreset;
  final bool enableWordByWordLyric;
  final bool enableDesktopLyric;
  final bool enableDesktopLyricLock;
  final String? lastSelectedOnlineAudioQualityName;
  final String? authToken;
  final String? refreshToken;
  final int? tokenExpiresAt;

  AppConfigState copyWith({
    String? apiBaseUrl,
    AppThemeMode? themeMode,
    AppThemeAccent? themeAccent,
    String? skinId,
    bool? enableSkinAnimation,
    bool? isMonochrome,
    String? localeCode,
    AppOnlineAudioQuality? onlineAudioQualityPreference,
    bool? autoCheckUpdates,
    AppPlayerBackgroundStyle? playerBackgroundStyle,
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
      enableSkinAnimation: enableSkinAnimation ?? this.enableSkinAnimation,
      isMonochrome: isMonochrome ?? this.isMonochrome,
      localeCode: localeCode ?? this.localeCode,
      onlineAudioQualityPreference:
          onlineAudioQualityPreference ?? this.onlineAudioQualityPreference,
      autoCheckUpdates: autoCheckUpdates ?? this.autoCheckUpdates,
      playerBackgroundStyle:
          playerBackgroundStyle ?? this.playerBackgroundStyle,
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
    isMonochrome: false,
    localeCode: 'zh',
    onlineAudioQualityPreference: AppOnlineAudioQuality.auto,
    autoCheckUpdates: true,
    playerBackgroundStyle: AppPlayerBackgroundStyle.albumCover,
    lyricHighlightMode: AppLyricHighlightMode.preset,
    lyricHighlightPreset: AppLyricHighlightColor.sky,
    lyricFontPreset: AppLyricFontPreset.medium,
    enableWordByWordLyric: true,
    enableDesktopLyric: false,
    enableDesktopLyricLock: false,
    apiBaseUrl: AppEnvironment.apiBaseUrl,
  );
}
