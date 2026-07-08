import 'package:flutter/material.dart';

import '../../../../shared/widgets/song_actions_sheet.dart';
import 'online_search_models.dart';

Future<void> showSearchSongActions({
  required BuildContext context,
  BuildContext? anchorContext,
  Offset? anchorPosition,
  required Map<String, dynamic> song,
  required String? coverUrl,
  required bool hasMv,
  required String sourceLabel,
  required VoidCallback onPlay,
  required VoidCallback onPlayNext,
  required VoidCallback onAddToPlaylist,
  VoidCallback? onDownload,
  VoidCallback? onAddToUserPlaylist,
  required VoidCallback onWatchMv,
  VoidCallback? onViewDetail,
  VoidCallback? onViewComment,
  String? albumActionLabel,
  VoidCallback? onViewAlbum,
  String? artistActionLabel,
  VoidCallback? onViewArtists,
  required VoidCallback onCopySongName,
  required VoidCallback onCopySongShareLink,
  required VoidCallback onSearchSameName,
  required VoidCallback onCopySongId,
}) {
  final title = songTitle(song);
  final subtitle = songSubtitle(song);
  return showSongActionsSheet(
    context: context,
    anchorContext: anchorContext,
    anchorPosition: anchorPosition,
    coverUrl: coverUrl,
    title: title,
    subtitle: subtitle,
    hasMv: hasMv,
    sourceLabel: sourceLabel,
    onPlay: onPlay,
    onPlayNext: onPlayNext,
    onAddToPlaylist: onAddToPlaylist,
    onDownload: onDownload,
    onAddToUserPlaylist: onAddToUserPlaylist,
    onWatchMv: onWatchMv,
    onViewDetail: onViewDetail,
    onViewComment: onViewComment,
    albumActionLabel: albumActionLabel,
    onViewAlbum: onViewAlbum,
    artistActionLabel: artistActionLabel,
    onViewArtists: onViewArtists,
    onCopySongName: onCopySongName,
    onCopySongShareLink: onCopySongShareLink,
    onSearchSameName: onSearchSameName,
    onCopySongId: onCopySongId,
  );
}
