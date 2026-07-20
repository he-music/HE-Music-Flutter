import 'package:flutter/material.dart';

import '../../config/app_theme_accent.dart';
import '../skin/app_skin_models.dart';

AppSkinPackage classicSkinForAccent(AppThemeAccent accent) {
  final lightScheme = _classicColorScheme(
    brightness: Brightness.light,
    seedColor: accent.lightSeed,
  );
  final darkScheme = _classicColorScheme(
    brightness: Brightness.dark,
    seedColor: accent.darkSeed,
  );
  return AppSkinPackage(
    metadata: const AppSkinMetadata(
      id: 'classic',
      nameKey: 'settings.skin.classic.name',
      descriptionKey: 'settings.skin.classic.description',
      allowsManualAccent: true,
      lightPreview: AppSkinAssetSlot.none(),
      darkPreview: AppSkinAssetSlot.none(),
    ),
    light: _classicBrightnessConfig(
      colorScheme: lightScheme,
      seedColor: accent.lightSeed,
    ),
    dark: _classicBrightnessConfig(
      colorScheme: darkScheme,
      seedColor: accent.darkSeed,
    ),
    icons: _classicIconCatalog,
  );
}

ColorScheme _classicColorScheme({
  required Brightness brightness,
  required Color seedColor,
}) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;
  return baseScheme.copyWith(
    surface: _tint(baseScheme.surface, seedColor, isDark ? 0.06 : 0.025),
    surfaceContainer: _tint(
      baseScheme.surfaceContainer,
      seedColor,
      isDark ? 0.08 : 0.035,
    ),
    surfaceContainerHigh: _tint(
      baseScheme.surfaceContainerHigh,
      seedColor,
      isDark ? 0.1 : 0.04,
    ),
    surfaceContainerHighest: _tint(
      baseScheme.surfaceContainerHighest,
      seedColor,
      isDark ? 0.12 : 0.05,
    ),
    primaryContainer: _tint(
      baseScheme.primaryContainer,
      seedColor,
      isDark ? 0.12 : 0.04,
    ),
    secondaryContainer: _tint(
      baseScheme.secondaryContainer,
      seedColor,
      isDark ? 0.08 : 0.03,
    ),
  );
}

AppSkinBrightnessConfig _classicBrightnessConfig({
  required ColorScheme colorScheme,
  required Color seedColor,
}) {
  final isDark = colorScheme.brightness == Brightness.dark;
  final scaffoldBackground = _tint(
    colorScheme.surface,
    seedColor,
    isDark ? 0.08 : 0.035,
  );
  return AppSkinBrightnessConfig(
    colorScheme: colorScheme,
    colors: AppSkinColors(
      scaffoldBackground: scaffoldBackground,
      canvasBackground: Colors.transparent,
      wallpaperFallback: scaffoldBackground,
      backgroundOverlay: Colors.transparent,
      cardBackground: colorScheme.surfaceContainerHigh.withValues(
        alpha: isDark ? 0.82 : 0.9,
      ),
      inputBackground: colorScheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.74 : 0.92,
      ),
      navigationBackground: colorScheme.surface.withValues(
        alpha: isDark ? 0.94 : 0.96,
      ),
      navigationIndicator: colorScheme.primaryContainer,
      bottomSheetBackground: colorScheme.surface,
      dialogBackground: colorScheme.surfaceContainerHigh,
      divider: colorScheme.outlineVariant.withValues(alpha: 0.6),
      snackBarBackground: _tint(
        isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.inverseSurface,
        seedColor,
        isDark ? 0.12 : 0.06,
      ),
      fixedControlSurface: colorScheme.surface,
      scrollingContentSurface: colorScheme.surfaceContainerHigh,
      border: colorScheme.outlineVariant,
      selectionIndicator: colorScheme.primary,
      shadow: Colors.black,
    ),
    surfaces: const AppSkinSurfaces(
      searchOpacity: 1,
      miniPlayerOpacity: 1,
      navigationOpacity: 1,
      scrollingContentOpacity: 1,
      bottomSheetOpacity: 1,
    ),
    geometry: const AppSkinGeometry(
      controlRadius: 20,
      cardRadius: 24,
      bottomSheetRadius: 32,
      blurSigma: 0,
      borderWidth: 0,
      shadowOpacity: 0.06,
      shadowBlurRadius: 12,
      shadowOffset: Offset(0, 4),
      showNavigationIndicatorPill: true,
    ),
    background: const AppSkinBackgroundConfig(
      wallpaper: AppSkinAssetSlot.none(),
      animation: AppSkinAnimationDescriptor.none(),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      overlayColor: Colors.transparent,
    ),
  );
}

final AppSkinIconCatalog _classicIconCatalog =
    AppSkinIconCatalog(<AppSkinIconRole, AppSkinIconSpec>{
      for (final role in AppSkinIconRole.values)
        role: AppSkinIconSpec(
          asset: const AppSkinAssetSlot.none(),
          fallbackIcon: classicIconForRole(role),
        ),
    });

IconData classicIconForRole(AppSkinIconRole role) {
  return switch (role) {
    AppSkinIconRole.navigationHome => Icons.home_outlined,
    AppSkinIconRole.navigationHomeSelected => Icons.home_rounded,
    AppSkinIconRole.navigationMy => Icons.account_circle_outlined,
    AppSkinIconRole.navigationMySelected => Icons.account_circle_rounded,
    AppSkinIconRole.homeRanking => Icons.leaderboard_rounded,
    AppSkinIconRole.homePlaylist => Icons.queue_music_rounded,
    AppSkinIconRole.homeArtist => Icons.person_search_rounded,
    AppSkinIconRole.homeVideo => Icons.ondemand_video_rounded,
    AppSkinIconRole.homeRadio => Icons.radio_rounded,
    AppSkinIconRole.search => Icons.search_rounded,
    AppSkinIconRole.back => Icons.arrow_back_rounded,
    AppSkinIconRole.forward => Icons.arrow_forward_ios_rounded,
    AppSkinIconRole.more => Icons.more_horiz_rounded,
    AppSkinIconRole.close => Icons.close_rounded,
    AppSkinIconRole.scan => Icons.qr_code_scanner_rounded,
    AppSkinIconRole.settings => Icons.settings_outlined,
    AppSkinIconRole.miniPlayerPlay => Icons.play_arrow_rounded,
    AppSkinIconRole.miniPlayerPause => Icons.pause_rounded,
    AppSkinIconRole.miniPlayerQueue => Icons.queue_music_rounded,
    AppSkinIconRole.songFavorite => Icons.favorite_border_rounded,
    AppSkinIconRole.songUnfavorite => Icons.favorite_rounded,
    AppSkinIconRole.songPlay => Icons.play_arrow_rounded,
    AppSkinIconRole.songPlayNext => Icons.skip_next_rounded,
    AppSkinIconRole.songAddToQueue => Icons.playlist_add_rounded,
    AppSkinIconRole.songDownload => Icons.download_rounded,
    AppSkinIconRole.songShare => Icons.share_outlined,
    AppSkinIconRole.songDetails => Icons.info_outline_rounded,
    AppSkinIconRole.songAddToPlaylist => Icons.playlist_add_rounded,
    AppSkinIconRole.songRemove => Icons.remove_circle_outline_rounded,
    AppSkinIconRole.songDelete => Icons.delete_outline_rounded,
    AppSkinIconRole.songWatchVideo => Icons.ondemand_video_rounded,
    AppSkinIconRole.songComments => Icons.forum_rounded,
    AppSkinIconRole.songAlbum => Icons.album_outlined,
    AppSkinIconRole.songArtist => Icons.person_outline_rounded,
    AppSkinIconRole.songCopyName => Icons.drive_file_rename_outline_rounded,
    AppSkinIconRole.songCopyId => Icons.copy_rounded,
    AppSkinIconRole.songSearchSameName => Icons.search_rounded,
    AppSkinIconRole.batchSelectAll => Icons.select_all_rounded,
    AppSkinIconRole.batchPlay => Icons.play_arrow_rounded,
    AppSkinIconRole.batchAddToPlaylist => Icons.playlist_add_rounded,
    AppSkinIconRole.batchDownload => Icons.download_rounded,
    AppSkinIconRole.myHistory => Icons.history_rounded,
    AppSkinIconRole.myLocalMusic => Icons.library_music_rounded,
    AppSkinIconRole.myDownloads => Icons.download_rounded,
    AppSkinIconRole.myCollection => Icons.favorite_border_rounded,
    AppSkinIconRole.myPlaylist => Icons.queue_music_rounded,
    AppSkinIconRole.settingsAppearance => Icons.palette_outlined,
    AppSkinIconRole.settingsPlayback => Icons.play_circle_outline_rounded,
    AppSkinIconRole.settingsLyrics => Icons.lyrics_outlined,
    AppSkinIconRole.settingsGeneral => Icons.tune_rounded,
    AppSkinIconRole.settingsAccount => Icons.person_outline_rounded,
    AppSkinIconRole.settingsThemeMode => Icons.palette_outlined,
    AppSkinIconRole.settingsThemeAccent => Icons.color_lens_outlined,
    AppSkinIconRole.settingsSkin => Icons.wallpaper_rounded,
    AppSkinIconRole.settingsSkinAnimation => Icons.animation_rounded,
    AppSkinIconRole.settingsMonochrome => Icons.contrast_rounded,
    AppSkinIconRole.settingsPlayerBackground => Icons.blur_on_rounded,
    AppSkinIconRole.settingsAudioQuality => Icons.high_quality_rounded,
    AppSkinIconRole.settingsLyricHighlight => Icons.brightness_1_outlined,
    AppSkinIconRole.settingsLyricFont => Icons.format_size_rounded,
    AppSkinIconRole.settingsWordByWord => Icons.text_fields_rounded,
    AppSkinIconRole.settingsDesktopLyric => Icons.lyrics_outlined,
    AppSkinIconRole.settingsDesktopLyricLock => Icons.lock_outline_rounded,
    AppSkinIconRole.settingsLanguage => Icons.language_rounded,
    AppSkinIconRole.settingsAutoUpdate => Icons.system_update_alt_rounded,
    AppSkinIconRole.settingsAbout => Icons.info_outline_rounded,
    AppSkinIconRole.settingsAccountProfile => Icons.badge_outlined,
    AppSkinIconRole.settingsLogin => Icons.login_rounded,
    AppSkinIconRole.settingsPassword => Icons.password_rounded,
    AppSkinIconRole.settingsDevices => Icons.devices_outlined,
    AppSkinIconRole.settingsLogout => Icons.logout_rounded,
  };
}

Color _tint(Color base, Color seed, double opacity) {
  return Color.alphaBlend(seed.withValues(alpha: opacity), base);
}
