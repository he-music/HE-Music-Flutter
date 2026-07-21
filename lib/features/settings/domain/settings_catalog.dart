import 'package:flutter/material.dart';

import 'settings_models.dart';

abstract final class SettingsSectionIds {
  static const appearance = 'appearance';
  static const playback = 'playback';
  static const lyrics = 'lyrics';
  static const general = 'general';
  static const account = 'account';
}

abstract final class SettingsGroupIds {
  static const appearanceTheme = 'appearance-theme';
  static const appearanceDisplay = 'appearance-display';
  static const playbackAudio = 'playback-audio';
  static const lyricsStyle = 'lyrics-style';
  static const lyricsBehavior = 'lyrics-behavior';
  static const lyricsDesktop = 'lyrics-desktop';
  static const generalPreferences = 'general-preferences';
  static const generalAbout = 'general-about';
  static const accountProfile = 'account-profile';
  static const accountSecurity = 'account-security';
  static const accountDevices = 'account-devices';
  static const accountSession = 'account-session';
}

abstract final class SettingsItemIds {
  static const themeMode = 'theme-mode';
  static const themeAccent = 'theme-accent';
  static const skin = 'skin';
  static const skinAnimation = 'skin-animation';
  static const monochrome = 'monochrome';
  static const onlineAudioQuality = 'online-audio-quality';
  static const lyricHighlightColor = 'lyric-highlight-color';
  static const lyricFontPreset = 'lyric-font-preset';
  static const wordByWordLyric = 'word-by-word-lyric';
  static const desktopLyric = 'desktop-lyric';
  static const desktopLyricLock = 'desktop-lyric-lock';
  static const language = 'language';
  static const autoCheckUpdates = 'auto-check-updates';
  static const about = 'about';
  static const accountProfile = 'account-profile';
  static const accountPassword = 'account-password';
  static const accountLogin = 'account-login';
  static const deviceManagement = 'device-management';
  static const accountLogout = 'account-logout';
}

const List<SettingsSectionNode> settingsSections = <SettingsSectionNode>[
  SettingsSectionNode(
    id: SettingsSectionIds.appearance,
    titleKey: 'settings.section.appearance',
    icon: Icons.palette_outlined,
  ),
  SettingsSectionNode(
    id: SettingsSectionIds.playback,
    titleKey: 'settings.section.playback',
    icon: Icons.play_circle_outline_rounded,
  ),
  SettingsSectionNode(
    id: SettingsSectionIds.lyrics,
    titleKey: 'settings.section.lyrics',
    icon: Icons.lyrics_outlined,
  ),
  SettingsSectionNode(
    id: SettingsSectionIds.general,
    titleKey: 'settings.section.general',
    icon: Icons.tune_rounded,
  ),
  SettingsSectionNode(
    id: SettingsSectionIds.account,
    titleKey: 'settings.section.account',
    icon: Icons.person_outline_rounded,
  ),
];

const List<SettingsGroupNode> settingsGroups = <SettingsGroupNode>[
  SettingsGroupNode(
    id: SettingsGroupIds.appearanceTheme,
    sectionId: SettingsSectionIds.appearance,
    titleKey: 'settings.group.appearance.theme',
  ),
  SettingsGroupNode(
    id: SettingsGroupIds.appearanceDisplay,
    sectionId: SettingsSectionIds.appearance,
    titleKey: 'settings.group.appearance.display',
  ),
  SettingsGroupNode(
    id: SettingsGroupIds.playbackAudio,
    sectionId: SettingsSectionIds.playback,
    titleKey: 'settings.group.playback.audio',
  ),
  SettingsGroupNode(
    id: SettingsGroupIds.lyricsStyle,
    sectionId: SettingsSectionIds.lyrics,
    titleKey: 'settings.group.lyrics.style',
  ),
  SettingsGroupNode(
    id: SettingsGroupIds.lyricsBehavior,
    sectionId: SettingsSectionIds.lyrics,
    titleKey: 'settings.group.lyrics.behavior',
  ),
  SettingsGroupNode(
    id: SettingsGroupIds.lyricsDesktop,
    sectionId: SettingsSectionIds.lyrics,
    titleKey: 'settings.group.lyrics.desktop',
  ),
  SettingsGroupNode(
    id: SettingsGroupIds.generalPreferences,
    sectionId: SettingsSectionIds.general,
    titleKey: 'settings.group.general.preferences',
  ),
  SettingsGroupNode(
    id: SettingsGroupIds.generalAbout,
    sectionId: SettingsSectionIds.general,
    titleKey: 'settings.group.general.about',
  ),
  SettingsGroupNode(
    id: SettingsGroupIds.accountProfile,
    sectionId: SettingsSectionIds.account,
    titleKey: 'settings.group.account.profile',
  ),
  SettingsGroupNode(
    id: SettingsGroupIds.accountSecurity,
    sectionId: SettingsSectionIds.account,
    titleKey: 'settings.group.account.security',
  ),
  SettingsGroupNode(
    id: SettingsGroupIds.accountDevices,
    sectionId: SettingsSectionIds.account,
    titleKey: 'settings.group.account.devices',
  ),
  SettingsGroupNode(
    id: SettingsGroupIds.accountSession,
    sectionId: SettingsSectionIds.account,
    titleKey: 'settings.group.account.session',
  ),
];

const List<SettingsItemNode> settingsItems = <SettingsItemNode>[
  SettingsItemNode(
    id: SettingsItemIds.themeMode,
    sectionId: SettingsSectionIds.appearance,
    groupId: SettingsGroupIds.appearanceTheme,
    titleKey: 'settings.theme',
    kind: SettingsItemKind.select,
    icon: Icons.palette_outlined,
    keywords: <String>['主题', '外观', '深色', '浅色'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.themeAccent,
    sectionId: SettingsSectionIds.appearance,
    groupId: SettingsGroupIds.appearanceTheme,
    titleKey: 'settings.theme_accent',
    kind: SettingsItemKind.select,
    icon: Icons.color_lens_outlined,
    keywords: <String>['主题色', '颜色', '外观'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.skin,
    sectionId: SettingsSectionIds.appearance,
    groupId: SettingsGroupIds.appearanceTheme,
    titleKey: 'settings.skin',
    kind: SettingsItemKind.navigation,
    icon: Icons.wallpaper_rounded,
    keywords: <String>['皮肤', '壁纸', '外观', 'skin'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.skinAnimation,
    sectionId: SettingsSectionIds.appearance,
    groupId: SettingsGroupIds.appearanceTheme,
    titleKey: 'settings.skin.animation',
    kind: SettingsItemKind.toggle,
    icon: Icons.animation_rounded,
    keywords: <String>['皮肤', '动画', '动态', 'animation'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.monochrome,
    sectionId: SettingsSectionIds.appearance,
    groupId: SettingsGroupIds.appearanceDisplay,
    titleKey: 'settings.monochrome',
    kind: SettingsItemKind.toggle,
    icon: Icons.contrast_rounded,
    keywords: <String>['黑白', '灰度', '外观'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.onlineAudioQuality,
    sectionId: SettingsSectionIds.playback,
    groupId: SettingsGroupIds.playbackAudio,
    titleKey: 'settings.audio_quality',
    kind: SettingsItemKind.select,
    icon: Icons.high_quality_rounded,
    keywords: <String>['音质', '播放', '无损'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.lyricHighlightColor,
    sectionId: SettingsSectionIds.lyrics,
    groupId: SettingsGroupIds.lyricsStyle,
    titleKey: 'settings.lyric_highlight_color',
    kind: SettingsItemKind.select,
    icon: Icons.brightness_1_outlined,
    keywords: <String>['歌词', '颜色', '高亮'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.lyricFontPreset,
    sectionId: SettingsSectionIds.lyrics,
    groupId: SettingsGroupIds.lyricsStyle,
    titleKey: 'settings.lyric_font_preset',
    kind: SettingsItemKind.select,
    icon: Icons.format_size_rounded,
    keywords: <String>['歌词', '大小', '字号'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.wordByWordLyric,
    sectionId: SettingsSectionIds.lyrics,
    groupId: SettingsGroupIds.lyricsBehavior,
    titleKey: 'settings.enable_word_by_word_lyric',
    kind: SettingsItemKind.toggle,
    icon: Icons.text_fields_rounded,
    keywords: <String>['歌词', '逐字', '逐词'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.desktopLyric,
    sectionId: SettingsSectionIds.lyrics,
    groupId: SettingsGroupIds.lyricsDesktop,
    titleKey: 'settings.desktop_lyric',
    kind: SettingsItemKind.toggle,
    icon: Icons.lyrics_outlined,
    keywords: <String>['桌面歌词', '悬浮窗', '歌词'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.desktopLyricLock,
    sectionId: SettingsSectionIds.lyrics,
    groupId: SettingsGroupIds.lyricsDesktop,
    titleKey: 'settings.desktop_lyric_lock',
    kind: SettingsItemKind.toggle,
    icon: Icons.lock_outline,
    keywords: <String>['锁定歌词', '锁定', '桌面歌词'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.language,
    sectionId: SettingsSectionIds.general,
    groupId: SettingsGroupIds.generalPreferences,
    titleKey: 'settings.language',
    kind: SettingsItemKind.select,
    icon: Icons.language_rounded,
    keywords: <String>['语言', '通用', '中文', 'English'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.autoCheckUpdates,
    sectionId: SettingsSectionIds.general,
    groupId: SettingsGroupIds.generalPreferences,
    titleKey: 'settings.auto_check_updates',
    kind: SettingsItemKind.toggle,
    icon: Icons.system_update_alt_rounded,
    keywords: <String>['更新', '通用', '自动'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.about,
    sectionId: SettingsSectionIds.general,
    groupId: SettingsGroupIds.generalAbout,
    titleKey: 'settings.about',
    kind: SettingsItemKind.navigation,
    icon: Icons.info_outline_rounded,
    keywords: <String>['关于', '版本', '更新'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.accountProfile,
    sectionId: SettingsSectionIds.account,
    groupId: SettingsGroupIds.accountProfile,
    titleKey: 'settings.account.profile',
    kind: SettingsItemKind.navigation,
    icon: Icons.badge_outlined,
    keywords: <String>['个人资料', '昵称', '头像', 'profile'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.accountLogin,
    sectionId: SettingsSectionIds.account,
    groupId: SettingsGroupIds.accountProfile,
    titleKey: 'settings.account.login',
    kind: SettingsItemKind.navigation,
    icon: Icons.login_rounded,
    keywords: <String>['登录', '帐号', 'login'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.accountPassword,
    sectionId: SettingsSectionIds.account,
    groupId: SettingsGroupIds.accountSecurity,
    titleKey: 'settings.account.password',
    kind: SettingsItemKind.navigation,
    icon: Icons.password_rounded,
    keywords: <String>['密码', '安全', 'password'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.deviceManagement,
    sectionId: SettingsSectionIds.account,
    groupId: SettingsGroupIds.accountDevices,
    titleKey: 'settings.device_management',
    kind: SettingsItemKind.navigation,
    icon: Icons.devices_outlined,
    keywords: <String>['设备', '管理', '登录', 'device'],
  ),
  SettingsItemNode(
    id: SettingsItemIds.accountLogout,
    sectionId: SettingsSectionIds.account,
    groupId: SettingsGroupIds.accountSession,
    titleKey: 'settings.logout',
    kind: SettingsItemKind.navigation,
    icon: Icons.logout_rounded,
    keywords: <String>['退出', '帐号', '登录', 'logout'],
  ),
];

SettingsSectionNode sectionById(String id) {
  return settingsSections.firstWhere((section) => section.id == id);
}

List<SettingsItemNode> itemsForSection(String sectionId) {
  return settingsItems
      .where((item) => item.sectionId == sectionId)
      .toList(growable: false);
}

List<SettingsGroupNode> groupsForSection(String sectionId) {
  return settingsGroups
      .where((group) => group.sectionId == sectionId)
      .toList(growable: false);
}

List<SettingsItemNode> itemsForGroup(String groupId) {
  return settingsItems
      .where((item) => item.groupId == groupId)
      .toList(growable: false);
}
