import '../../../../app/config/app_config_state.dart';
import '../../../../app/config/app_online_audio_quality.dart';
import '../../../../app/config/app_player_background_style.dart';
import '../../../../app/config/app_theme_mode.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../domain/settings_catalog.dart';

typedef SettingsItemSubtitleBuilder = String Function(AppConfigState config);

class SettingsItemPresentation {
  const SettingsItemPresentation({required this.subtitleBuilder});

  final SettingsItemSubtitleBuilder subtitleBuilder;
}

final Map<String, SettingsItemPresentation> settingsItemPresentations =
    <String, SettingsItemPresentation>{
      SettingsItemIds.themeMode: SettingsItemPresentation(
        subtitleBuilder: (config) => _themeModeLabel(config.themeMode, config),
      ),
      SettingsItemIds.themeAccent: SettingsItemPresentation(
        subtitleBuilder: (config) => AppI18n.format(
          config,
          'settings.theme_accent.current',
          <String, String>{'value': config.themeAccent.label},
        ),
      ),
      SettingsItemIds.monochrome: SettingsItemPresentation(
        subtitleBuilder: (config) =>
            AppI18n.t(config, 'settings.monochrome.desc'),
      ),
      SettingsItemIds.playerBackgroundStyle: SettingsItemPresentation(
        subtitleBuilder: (config) => _playerBackgroundStyleDescription(
          config.playerBackgroundStyle,
          config,
        ),
      ),
      SettingsItemIds.onlineAudioQuality: SettingsItemPresentation(
        subtitleBuilder: (config) => _qualitySubtitle(
          config.onlineAudioQualityPreference,
          config.lastSelectedOnlineAudioQualityName,
        ),
      ),
      SettingsItemIds.lyricHighlightColor: SettingsItemPresentation(
        subtitleBuilder: (config) =>
            AppI18n.t(config, 'settings.lyric_highlight_color.desc'),
      ),
      SettingsItemIds.lyricFontPreset: SettingsItemPresentation(
        subtitleBuilder: (config) =>
            AppI18n.t(config, 'settings.lyric_font_preset.desc'),
      ),
      SettingsItemIds.wordByWordLyric: SettingsItemPresentation(
        subtitleBuilder: (config) =>
            AppI18n.t(config, 'settings.enable_word_by_word_lyric.desc'),
      ),
      SettingsItemIds.desktopLyric: SettingsItemPresentation(
        subtitleBuilder: (config) =>
            AppI18n.t(config, 'settings.desktop_lyric.desc'),
      ),
      SettingsItemIds.desktopLyricLock: SettingsItemPresentation(
        subtitleBuilder: (config) =>
            AppI18n.t(config, 'settings.desktop_lyric_lock.desc'),
      ),
      SettingsItemIds.language: SettingsItemPresentation(
        subtitleBuilder: (config) => _languageLabel(config.localeCode, config),
      ),
      SettingsItemIds.autoCheckUpdates: SettingsItemPresentation(
        subtitleBuilder: (config) =>
            AppI18n.t(config, 'settings.auto_check_updates.desc'),
      ),
      SettingsItemIds.about: SettingsItemPresentation(
        subtitleBuilder: (config) => AppI18n.t(config, 'settings.about.desc'),
      ),
      SettingsItemIds.accountProfile: SettingsItemPresentation(
        subtitleBuilder: (config) =>
            AppI18n.t(config, 'settings.account.profile.desc'),
      ),
      SettingsItemIds.accountPassword: SettingsItemPresentation(
        subtitleBuilder: (config) =>
            AppI18n.t(config, 'settings.account.password.desc'),
      ),
      SettingsItemIds.accountLogin: SettingsItemPresentation(
        subtitleBuilder: (config) =>
            AppI18n.t(config, 'settings.account.login.desc'),
      ),
      SettingsItemIds.deviceManagement: SettingsItemPresentation(
        subtitleBuilder: (config) =>
            AppI18n.t(config, 'settings.device_management.desc'),
      ),
      SettingsItemIds.accountLogout: SettingsItemPresentation(
        subtitleBuilder: (config) => AppI18n.t(config, 'settings.logout.desc'),
      ),
    };

String settingsItemSubtitle(String itemId, AppConfigState config) {
  final presentation = settingsItemPresentations[itemId];
  if (presentation == null) {
    return '';
  }
  return presentation.subtitleBuilder(config);
}

String _playerBackgroundStyleDescription(
  AppPlayerBackgroundStyle style,
  AppConfigState config,
) {
  return switch (style) {
    AppPlayerBackgroundStyle.albumCover => AppI18n.t(
      config,
      'settings.player_background_style.album_cover.desc',
    ),
    AppPlayerBackgroundStyle.fluid => AppI18n.t(
      config,
      'settings.player_background_style.fluid.desc',
    ),
    AppPlayerBackgroundStyle.artistPhoto => AppI18n.t(
      config,
      'settings.player_background_style.artist_photo.desc',
    ),
  };
}

String _qualitySubtitle(
  AppOnlineAudioQuality preference,
  String? lastSelected,
) {
  if (!preference.isAuto) {
    return preference.tip;
  }
  return AppOnlineAudioQuality.autoDescription(
    lastSelectedQualityName: lastSelected,
  );
}

String _themeModeLabel(AppThemeMode mode, AppConfigState config) {
  return switch (mode) {
    AppThemeMode.system => AppI18n.t(config, 'my.theme.system'),
    AppThemeMode.light => AppI18n.t(config, 'my.theme.light'),
    AppThemeMode.dark => AppI18n.t(config, 'my.theme.dark'),
  };
}

String _languageLabel(String localeCode, AppConfigState config) {
  return switch (localeCode) {
    'system' => AppI18n.t(config, 'settings.lang.system'),
    'en' => AppI18n.t(config, 'settings.lang.en'),
    _ => AppI18n.t(config, 'settings.lang.zh_cn'),
  };
}
