import 'package:flutter/material.dart';

import '../../config/app_theme_accent.dart';
import '../skin/app_skin_models.dart';
import 'classic_skin.dart';

AppSkinPackage citySoundCreatorSkin() {
  // 固定模板只提供完整的经典图标回退，不读取用户当前主题色。
  final base = classicSkinForAccent(AppThemeAccent.graphite);
  return base.copyWith(
    metadata: const AppSkinMetadata(
      id: 'city_sound_creator',
      nameKey: 'settings.skin.city_sound_creator.name',
      descriptionKey: 'settings.skin.city_sound_creator.description',
      allowsManualAccent: false,
      lightPreview: AppSkinAssetSlot.asset(
        AppSkinAssetDescriptor(
          path: 'assets/skins/city_sound_creator/preview_light.png',
          type: AppSkinAssetType.rasterImage,
        ),
      ),
      darkPreview: AppSkinAssetSlot.asset(
        AppSkinAssetDescriptor(
          path: 'assets/skins/city_sound_creator/preview_dark.png',
          type: AppSkinAssetType.rasterImage,
        ),
      ),
    ),
    light: _brightnessConfig(brightness: Brightness.light),
    dark: _brightnessConfig(brightness: Brightness.dark),
    icons: _iconCatalog(base.icons),
  );
}

const _iconDirectory = 'assets/skins/city_sound_creator/icons';
const _iconSourceColor = Color(0xFFE85D52);
const _backgroundFit = BoxFit.cover;
const _backgroundAlignment = Alignment(0.36, -0.12);
const _ambientAnimation = AppSkinAnimationDescriptor.rive(
  asset: AppSkinAssetDescriptor(
    path: 'assets/skins/city_sound_creator/ambient.riv',
    type: AppSkinAssetType.rive,
  ),
  artboard: 'CitySoundAmbient',
  stateMachine: 'AmbientLoop',
  fit: _backgroundFit,
  alignment: _backgroundAlignment,
  opacity: 0.92,
);

const _iconAssetNames = <AppSkinIconRole, String>{
  AppSkinIconRole.navigationHome: 'navigation_home.svg',
  AppSkinIconRole.navigationHomeSelected: 'navigation_home_selected.svg',
  AppSkinIconRole.navigationMy: 'navigation_my.svg',
  AppSkinIconRole.navigationMySelected: 'navigation_my_selected.svg',
  AppSkinIconRole.homeRanking: 'home_ranking.svg',
  AppSkinIconRole.homePlaylist: 'home_playlist.svg',
  AppSkinIconRole.homeArtist: 'home_artist.svg',
  AppSkinIconRole.homeVideo: 'home_video.svg',
  AppSkinIconRole.homeRadio: 'home_radio.svg',
  AppSkinIconRole.search: 'search.svg',
  AppSkinIconRole.searchSubmit: 'forward.svg',
  AppSkinIconRole.searchHistoryClear: 'song_delete.svg',
  AppSkinIconRole.back: 'back.svg',
  AppSkinIconRole.forward: 'forward.svg',
  AppSkinIconRole.more: 'more.svg',
  AppSkinIconRole.close: 'close.svg',
  AppSkinIconRole.scan: 'scan.svg',
  AppSkinIconRole.settings: 'settings_general.svg',
  AppSkinIconRole.miniPlayerPlay: 'mini_player_play.svg',
  AppSkinIconRole.miniPlayerPause: 'mini_player_pause.svg',
  AppSkinIconRole.miniPlayerQueue: 'mini_player_queue.svg',
  AppSkinIconRole.queueClear: 'song_delete.svg',
  AppSkinIconRole.songFavorite: 'song_favorite.svg',
  AppSkinIconRole.songUnfavorite: 'song_unfavorite.svg',
  AppSkinIconRole.songPlay: 'mini_player_play.svg',
  AppSkinIconRole.songPlayNext: 'song_play_next.svg',
  AppSkinIconRole.songAddToQueue: 'song_add_queue.svg',
  AppSkinIconRole.songDownload: 'song_download.svg',
  AppSkinIconRole.songShare: 'song_share.svg',
  AppSkinIconRole.songDetails: 'song_details.svg',
  AppSkinIconRole.songAddToPlaylist: 'song_add_playlist.svg',
  AppSkinIconRole.songRemove: 'song_remove.svg',
  AppSkinIconRole.songDelete: 'song_delete.svg',
  AppSkinIconRole.songWatchVideo: 'home_video.svg',
  AppSkinIconRole.songComments: 'song_comments.svg',
  AppSkinIconRole.songAlbum: 'settings_playback.svg',
  AppSkinIconRole.songArtist: 'home_artist.svg',
  AppSkinIconRole.songCopyName: 'song_copy_name.svg',
  AppSkinIconRole.songCopyId: 'song_copy_id.svg',
  AppSkinIconRole.songSearchSameName: 'search.svg',
  AppSkinIconRole.batchSelectAll: 'batch_select_all.svg',
  AppSkinIconRole.batchDeselectAll: 'batch_deselect_all.svg',
  AppSkinIconRole.batchPlay: 'mini_player_play.svg',
  AppSkinIconRole.batchAddToQueue: 'song_add_queue.svg',
  AppSkinIconRole.batchAddToPlaylist: 'song_add_playlist.svg',
  AppSkinIconRole.batchDownload: 'song_download.svg',
  AppSkinIconRole.myHistory: 'my_history.svg',
  AppSkinIconRole.myLocalMusic: 'my_local_music.svg',
  AppSkinIconRole.localLibraryScan: 'my_local_music.svg',
  AppSkinIconRole.localLibraryClear: 'song_delete.svg',
  AppSkinIconRole.myDownloads: 'song_download.svg',
  AppSkinIconRole.myCollection: 'song_favorite.svg',
  AppSkinIconRole.myCollectionRefresh: 'refresh.svg',
  AppSkinIconRole.myCollectionRemove: 'song_unfavorite.svg',
  AppSkinIconRole.myPlaylist: 'home_playlist.svg',
  AppSkinIconRole.myPlaylistCreate: 'song_add_playlist.svg',
  AppSkinIconRole.settingsAppearance: 'settings_appearance.svg',
  AppSkinIconRole.settingsPlayback: 'settings_playback.svg',
  AppSkinIconRole.settingsLyrics: 'settings_lyrics.svg',
  AppSkinIconRole.settingsGeneral: 'settings_general.svg',
  AppSkinIconRole.settingsAccount: 'settings_account.svg',
  AppSkinIconRole.settingsThemeMode: 'settings_appearance.svg',
  AppSkinIconRole.settingsThemeAccent: 'settings_appearance.svg',
  AppSkinIconRole.settingsSkin: 'settings_skin.svg',
  AppSkinIconRole.settingsSkinAnimation: 'settings_animation.svg',
  AppSkinIconRole.settingsMonochrome: 'settings_monochrome.svg',
  AppSkinIconRole.settingsPlayerBackground: 'settings_player_background.svg',
  AppSkinIconRole.settingsAudioQuality: 'settings_audio_quality.svg',
  AppSkinIconRole.settingsLyricHighlight: 'settings_highlight.svg',
  AppSkinIconRole.settingsLyricFont: 'settings_font.svg',
  AppSkinIconRole.settingsWordByWord: 'settings_lyrics.svg',
  AppSkinIconRole.settingsDesktopLyric: 'settings_lyrics.svg',
  AppSkinIconRole.settingsDesktopLyricLock: 'settings_lock.svg',
  AppSkinIconRole.settingsLanguage: 'settings_language.svg',
  AppSkinIconRole.settingsAutoUpdate: 'settings_update.svg',
  AppSkinIconRole.settingsAbout: 'song_details.svg',
  AppSkinIconRole.settingsAccountProfile: 'settings_account.svg',
  AppSkinIconRole.settingsLogin: 'settings_login.svg',
  AppSkinIconRole.settingsPassword: 'settings_password.svg',
  AppSkinIconRole.settingsDevices: 'settings_devices.svg',
  AppSkinIconRole.settingsLogout: 'settings_logout.svg',
};

AppSkinIconCatalog _iconCatalog(AppSkinIconCatalog fallback) {
  return fallback.copyWith(
    overrides: <AppSkinIconRole, AppSkinIconSpec>{
      for (final entry in _iconAssetNames.entries)
        entry.key: fallback[entry.key]!.copyWith(
          asset: AppSkinAssetSlot.asset(
            AppSkinAssetDescriptor(
              path: '$_iconDirectory/${entry.value}',
              type: AppSkinAssetType.svg,
              themeColorSource:
                  entry.value == 'back.svg' || entry.value == 'forward.svg'
                  ? null
                  : _iconSourceColor,
            ),
          ),
        ),
    },
  );
}

AppSkinBrightnessConfig _brightnessConfig({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final scheme = _colorScheme(brightness);
  final wallpaperFallback = isDark
      ? const Color(0xFF151918)
      : const Color(0xFFF1F3F1);
  final fixedSurface = isDark
      ? const Color(0xFF202624)
      : const Color(0xFFF8FAF8);
  final scrollingSurface = isDark
      ? const Color(0xFF252B29)
      : const Color(0xFFF4F6F4);
  final overlay = isDark ? const Color(0x42111615) : const Color(0x7AFFFFFF);
  return AppSkinBrightnessConfig(
    colorScheme: scheme,
    colors: AppSkinColors(
      scaffoldBackground: Colors.transparent,
      canvasBackground: Colors.transparent,
      wallpaperFallback: wallpaperFallback,
      backgroundOverlay: overlay,
      cardBackground: scrollingSurface.withValues(alpha: 0),
      inputBackground: fixedSurface.withValues(alpha: isDark ? 0.82 : 0.84),
      navigationBackground: fixedSurface.withValues(alpha: isDark ? 0.88 : 0.9),
      navigationIndicator: const Color(0xFFE85D52).withValues(alpha: 0.18),
      bottomSheetBackground: isDark
          ? const Color(0xF51D2221)
          : const Color(0xF7F8FAF8),
      dialogBackground: isDark
          ? const Color(0xF5202524)
          : const Color(0xFAF8FAF8),
      divider: scheme.outlineVariant.withValues(alpha: 0.62),
      snackBarBackground: isDark
          ? const Color(0xFF303735)
          : const Color(0xFF292F2D),
      fixedControlSurface: fixedSurface,
      scrollingContentSurface: scrollingSurface,
      border: isDark ? const Color(0xFF53605C) : const Color(0xFFB9C2BE),
      selectionIndicator: const Color(0xFFE85D52),
      shadow: Colors.black,
    ),
    surfaces: AppSkinSurfaces(
      searchOpacity: isDark ? 0.82 : 0.84,
      miniPlayerOpacity: isDark ? 0.88 : 0.9,
      navigationOpacity: isDark ? 0.88 : 0.9,
      scrollingContentOpacity: 0,
      bottomSheetOpacity: isDark ? 0.96 : 0.97,
    ),
    geometry: const AppSkinGeometry(
      controlRadius: 20,
      cardRadius: 18,
      bottomSheetRadius: 28,
      blurSigma: 8,
      borderWidth: 0.8,
      shadowOpacity: 0.12,
      shadowBlurRadius: 12,
      shadowOffset: Offset(0, 4),
      showNavigationIndicatorPill: false,
    ),
    background: AppSkinBackgroundConfig(
      wallpaper: AppSkinAssetSlot.asset(
        AppSkinAssetDescriptor(
          path:
              'assets/skins/city_sound_creator/'
              'wallpaper_${isDark ? 'dark' : 'light'}.png',
          type: AppSkinAssetType.rasterImage,
        ),
      ),
      animation: _ambientAnimation,
      fit: _backgroundFit,
      alignment: _backgroundAlignment,
      overlayColor: overlay,
    ),
  );
}

ColorScheme _colorScheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFFE85D52),
    secondary: const Color(0xFF138F87),
    tertiary: const Color(0xFFE7B93E),
    brightness: brightness,
  );
  if (isDark) {
    return base.copyWith(
      primary: const Color(0xFFFF8176),
      onPrimary: const Color(0xFF3D0502),
      primaryContainer: const Color(0xFF6E2722),
      onPrimaryContainer: const Color(0xFFFFDAD6),
      secondary: const Color(0xFF58D7CD),
      onSecondary: const Color(0xFF003733),
      secondaryContainer: const Color(0xFF07514C),
      onSecondaryContainer: const Color(0xFF9AF2EA),
      tertiary: const Color(0xFFF4CD67),
      onTertiary: const Color(0xFF3B2F00),
      surface: const Color(0xFF151918),
      onSurface: const Color(0xFFE6EAE7),
      onSurfaceVariant: const Color(0xFFC1C9C5),
      surfaceContainerLowest: const Color(0xFF0F1312),
      surfaceContainerLow: const Color(0xFF1B201F),
      surfaceContainer: const Color(0xFF202624),
      surfaceContainerHigh: const Color(0xFF292F2D),
      surfaceContainerHighest: const Color(0xFF343B38),
      outline: const Color(0xFF8B9591),
      outlineVariant: const Color(0xFF414A47),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
    );
  }
  return base.copyWith(
    primary: const Color(0xFFB9342E),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFFFDAD6),
    onPrimaryContainer: const Color(0xFF410003),
    secondary: const Color(0xFF006A63),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFF9AF2EA),
    onSecondaryContainer: const Color(0xFF00201D),
    tertiary: const Color(0xFF735C00),
    onTertiary: Colors.white,
    surface: const Color(0xFFF7F9F7),
    onSurface: const Color(0xFF1A1C1B),
    onSurfaceVariant: const Color(0xFF414846),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF1F4F1),
    surfaceContainer: const Color(0xFFEBEEEB),
    surfaceContainerHigh: const Color(0xFFE5E9E6),
    surfaceContainerHighest: const Color(0xFFDDE2DE),
    outline: const Color(0xFF717976),
    outlineVariant: const Color(0xFFC1C9C5),
    error: const Color(0xFFBA1A1A),
    onError: Colors.white,
  );
}
