import '../../../../app/config/app_config_state.dart';
import '../../../../app/config/app_online_audio_quality.dart';
import '../../../../app/config/app_theme_mode.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../app/theme/skin/app_skin_registry.dart';
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
        subtitleBuilder: (config) {
          final skin = AppSkinRegistry.builtIn(
            config.themeAccent,
          ).resolve(config.skinId);
          if (!skin.metadata.allowsManualAccent) {
            return AppI18n.t(config, 'settings.theme_accent.follows_skin');
          }
          return AppI18n.format(
            config,
            'settings.theme_accent.current',
            <String, String>{'value': config.themeAccent.label},
          );
        },
      ),
      SettingsItemIds.skin: SettingsItemPresentation(
        subtitleBuilder: (config) => AppI18n.t(
          config,
          AppSkinRegistry.builtIn(
            config.themeAccent,
          ).resolve(config.skinId).metadata.descriptionKey,
        ),
      ),
      SettingsItemIds.skinAnimation: SettingsItemPresentation(
        subtitleBuilder: (config) {
          final skin = AppSkinRegistry.builtIn(
            config.themeAccent,
          ).resolve(config.skinId);
          final supportsAnimation =
              skin.light.background.animation
                  is AppSkinRiveAnimationDescriptor ||
              skin.dark.background.animation is AppSkinRiveAnimationDescriptor;
          return AppI18n.t(
            config,
            supportsAnimation
                ? 'settings.skin.animation.desc'
                : 'settings.skin.animation.static',
          );
        },
      ),
      SettingsItemIds.monochrome: SettingsItemPresentation(
        subtitleBuilder: (config) =>
            AppI18n.t(config, 'settings.monochrome.desc'),
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

AppSkinIconRole settingsSectionIconRole(String sectionId) {
  return switch (sectionId) {
    SettingsSectionIds.appearance => AppSkinIconRole.settingsAppearance,
    SettingsSectionIds.playback => AppSkinIconRole.settingsPlayback,
    SettingsSectionIds.lyrics => AppSkinIconRole.settingsLyrics,
    SettingsSectionIds.general => AppSkinIconRole.settingsGeneral,
    SettingsSectionIds.account => AppSkinIconRole.settingsAccount,
    _ => AppSkinIconRole.settingsGeneral,
  };
}

AppSkinIconRole settingsItemIconRole(String itemId) {
  return switch (itemId) {
    SettingsItemIds.themeMode => AppSkinIconRole.settingsThemeMode,
    SettingsItemIds.themeAccent => AppSkinIconRole.settingsThemeAccent,
    SettingsItemIds.skin => AppSkinIconRole.settingsSkin,
    SettingsItemIds.skinAnimation => AppSkinIconRole.settingsSkinAnimation,
    SettingsItemIds.monochrome => AppSkinIconRole.settingsMonochrome,
    SettingsItemIds.onlineAudioQuality => AppSkinIconRole.settingsAudioQuality,
    SettingsItemIds.lyricHighlightColor =>
      AppSkinIconRole.settingsLyricHighlight,
    SettingsItemIds.lyricFontPreset => AppSkinIconRole.settingsLyricFont,
    SettingsItemIds.wordByWordLyric => AppSkinIconRole.settingsWordByWord,
    SettingsItemIds.desktopLyric => AppSkinIconRole.settingsDesktopLyric,
    SettingsItemIds.desktopLyricLock =>
      AppSkinIconRole.settingsDesktopLyricLock,
    SettingsItemIds.language => AppSkinIconRole.settingsLanguage,
    SettingsItemIds.autoCheckUpdates => AppSkinIconRole.settingsAutoUpdate,
    SettingsItemIds.about => AppSkinIconRole.settingsAbout,
    SettingsItemIds.accountProfile => AppSkinIconRole.settingsAccountProfile,
    SettingsItemIds.accountLogin => AppSkinIconRole.settingsLogin,
    SettingsItemIds.accountPassword => AppSkinIconRole.settingsPassword,
    SettingsItemIds.deviceManagement => AppSkinIconRole.settingsDevices,
    SettingsItemIds.accountLogout => AppSkinIconRole.settingsLogout,
    _ => AppSkinIconRole.settingsGeneral,
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
