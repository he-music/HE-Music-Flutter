import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../models/he_music_models.dart';
import 'song_list_item.dart';

class OnlineSongListItem extends ConsumerWidget {
  const OnlineSongListItem({
    required this.song,
    this.coverUrl,
    this.coverBytes,
    this.isLiked = false,
    this.isCurrent = false,
    this.selectable = false,
    this.selected = false,
    this.showActions = true,
    this.artistAlbumText,
    this.subtitleText = '',
    this.tags,
    this.showMoreVersionButton = false,
    this.onTap,
    this.onSelectTap,
    this.onLikeTap,
    this.onMoreTap,
    this.onMoreVersionTap,
    super.key,
  });

  final SongInfo song;
  final String? coverUrl;
  final Uint8List? coverBytes;
  final bool isLiked;
  final bool isCurrent;
  final bool selectable;
  final bool selected;
  final bool showActions;
  final String? artistAlbumText;
  final String subtitleText;
  final List<String>? tags;
  final bool showMoreVersionButton;
  final VoidCallback? onTap;
  final VoidCallback? onSelectTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onMoreTap;
  final VoidCallback? onMoreVersionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return SongListItem(
      data: SongListItemData.fromSongInfo(
        song: song,
        artistAlbumText: artistAlbumText,
        subtitleText: subtitleText,
        coverUrl: coverUrl,
        coverBytes: coverBytes,
        tags: tags,
        isCurrent: isCurrent,
        showMoreVersionButton: showMoreVersionButton,
        originalTagLabel: AppI18n.t(config, 'song.tag.original'),
      ),
      isLiked: isLiked,
      selectable: selectable,
      selected: selected,
      showActions: showActions,
      onTap: onTap,
      onSelectTap: onSelectTap,
      onLikeTap: onLikeTap,
      onMoreTap: onMoreTap,
      onMoreVersionTap: onMoreVersionTap,
      moreVersionLabel: AppI18n.t(config, 'song.more_versions'),
    );
  }
}
