import 'package:flutter/cupertino.dart';

import 'skin/app_skin_models.dart';

/// SDK icon equivalents for the classic skin; authored skin artwork wins.
IconData cupertinoIconForRole(AppSkinIconRole role) => switch (role) {
  AppSkinIconRole.navigationHome => CupertinoIcons.house,
  AppSkinIconRole.navigationHomeSelected => CupertinoIcons.house_fill,
  AppSkinIconRole.navigationMy => CupertinoIcons.person_crop_circle,
  AppSkinIconRole.navigationMySelected =>
    CupertinoIcons.person_crop_circle_fill,
  AppSkinIconRole.homeRanking => CupertinoIcons.chart_bar,
  AppSkinIconRole.homePlaylist ||
  AppSkinIconRole.myPlaylist => CupertinoIcons.music_albums,
  AppSkinIconRole.homeArtist ||
  AppSkinIconRole.songArtist => CupertinoIcons.person_2,
  AppSkinIconRole.homeVideo ||
  AppSkinIconRole.songWatchVideo => CupertinoIcons.play_rectangle,
  AppSkinIconRole.homeRadio => CupertinoIcons.antenna_radiowaves_left_right,
  AppSkinIconRole.search ||
  AppSkinIconRole.songSearchSameName => CupertinoIcons.search,
  AppSkinIconRole.searchSubmit => CupertinoIcons.arrow_right,
  AppSkinIconRole.back => CupertinoIcons.chevron_back,
  AppSkinIconRole.forward => CupertinoIcons.chevron_forward,
  AppSkinIconRole.more => CupertinoIcons.ellipsis,
  AppSkinIconRole.close => CupertinoIcons.xmark,
  AppSkinIconRole.scan ||
  AppSkinIconRole.localLibraryScan => CupertinoIcons.viewfinder,
  AppSkinIconRole.settings ||
  AppSkinIconRole.settingsGeneral => CupertinoIcons.gear,
  AppSkinIconRole.miniPlayerPlay ||
  AppSkinIconRole.songPlay ||
  AppSkinIconRole.batchPlay => CupertinoIcons.play_fill,
  AppSkinIconRole.miniPlayerPause => CupertinoIcons.pause_fill,
  AppSkinIconRole.miniPlayerQueue => CupertinoIcons.music_note_list,
  AppSkinIconRole.searchHistoryClear ||
  AppSkinIconRole.queueClear ||
  AppSkinIconRole.songDelete ||
  AppSkinIconRole.localLibraryClear => CupertinoIcons.trash,
  AppSkinIconRole.songFavorite => CupertinoIcons.heart,
  AppSkinIconRole.songUnfavorite => CupertinoIcons.heart_fill,
  AppSkinIconRole.songPlayNext => CupertinoIcons.text_insert,
  AppSkinIconRole.songAddToQueue ||
  AppSkinIconRole.batchAddToQueue => CupertinoIcons.text_badge_plus,
  AppSkinIconRole.songDownload ||
  AppSkinIconRole.batchDownload ||
  AppSkinIconRole.myDownloads => CupertinoIcons.arrow_down_to_line,
  AppSkinIconRole.songShare => CupertinoIcons.share,
  AppSkinIconRole.songDetails ||
  AppSkinIconRole.settingsAbout => CupertinoIcons.info_circle,
  AppSkinIconRole.songAddToPlaylist ||
  AppSkinIconRole.batchAddToPlaylist ||
  AppSkinIconRole.myPlaylistCreate => CupertinoIcons.add_circled,
  AppSkinIconRole.songRemove ||
  AppSkinIconRole.myCollectionRemove => CupertinoIcons.minus_circle,
  AppSkinIconRole.songComments => CupertinoIcons.chat_bubble,
  AppSkinIconRole.songAlbum => CupertinoIcons.square_stack,
  AppSkinIconRole.songCopyName ||
  AppSkinIconRole.songCopyId => CupertinoIcons.doc_on_doc,
  AppSkinIconRole.batchSelectAll => CupertinoIcons.checkmark_circle_fill,
  AppSkinIconRole.batchDeselectAll => CupertinoIcons.circle,
  AppSkinIconRole.myHistory => CupertinoIcons.clock,
  AppSkinIconRole.myLocalMusic => CupertinoIcons.folder,
  AppSkinIconRole.myCollection => CupertinoIcons.heart,
  AppSkinIconRole.myCollectionRefresh ||
  AppSkinIconRole.settingsAutoUpdate => CupertinoIcons.arrow_clockwise,
  AppSkinIconRole.settingsAppearance ||
  AppSkinIconRole.settingsThemeAccent => CupertinoIcons.paintbrush,
  AppSkinIconRole.settingsPlayback => CupertinoIcons.play_circle,
  AppSkinIconRole.settingsLyrics => CupertinoIcons.text_alignleft,
  AppSkinIconRole.settingsAccount ||
  AppSkinIconRole.settingsAccountProfile => CupertinoIcons.person_crop_circle,
  AppSkinIconRole.settingsThemeMode => CupertinoIcons.circle_lefthalf_fill,
  AppSkinIconRole.settingsSkin ||
  AppSkinIconRole.settingsPlayerBackground => CupertinoIcons.photo,
  AppSkinIconRole.settingsSkinAnimation => CupertinoIcons.sparkles,
  AppSkinIconRole.settingsMonochrome => CupertinoIcons.circle_righthalf_fill,
  AppSkinIconRole.settingsAudioQuality => CupertinoIcons.waveform,
  AppSkinIconRole.settingsLyricHighlight => CupertinoIcons.pencil,
  AppSkinIconRole.settingsLyricFont => CupertinoIcons.textformat,
  AppSkinIconRole.settingsWordByWord => CupertinoIcons.text_cursor,
  AppSkinIconRole.settingsDesktopLyric => CupertinoIcons.desktopcomputer,
  AppSkinIconRole.settingsDesktopLyricLock ||
  AppSkinIconRole.settingsPassword => CupertinoIcons.lock,
  AppSkinIconRole.settingsLanguage => CupertinoIcons.globe,
  AppSkinIconRole.settingsLogin => CupertinoIcons.square_arrow_right,
  AppSkinIconRole.settingsDevices => CupertinoIcons.device_phone_portrait,
  AppSkinIconRole.settingsLogout => CupertinoIcons.square_arrow_left,
};
