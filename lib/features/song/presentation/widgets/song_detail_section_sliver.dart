import 'package:flutter/material.dart';

import '../../../sheet_music/presentation/widgets/sheet_music_list.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/layout/adaptive_media_grid_spec.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/widgets/media_grid_card.dart';
import '../../../../shared/widgets/online_song_list_item.dart';
import '../../../../shared/widgets/video_item.dart';
import '../../domain/entities/song_detail_section.dart';

typedef SongDetailStatusBuilder =
    Widget Function(
      BuildContext context,
      SongInfo song,
      Widget Function(bool isLiked, bool isCurrent) builder,
    );

Widget buildSongDetailSectionSliver({
  required Key key,
  required SongDetailSection section,
  required AdaptiveMediaGridSpec gridSpec,
  required String songId,
  required String platform,
  required String moreLabel,
  required VoidCallback onMoreSheetMusic,
  required void Function(List<SongInfo> songs, int index) onTapSong,
  required ValueChanged<AlbumInfo> onTapAlbum,
  required ValueChanged<PlaylistInfo> onTapPlaylist,
  required ValueChanged<MvInfo> onTapMv,
  required ValueChanged<SongInfo> onMoreSong,
  required Future<void> Function(SongInfo) onLikeSong,
  required SongDetailStatusBuilder buildSongStatus,
  required String Function(SongInfo) resolveSongCover,
  required String Function(String cover, String platform) resolveCover,
}) {
  final Widget resources = switch (section.resourceType) {
    'sheet_music' => SheetMusicListSliver(
      sheets: section.sheetMusic,
      platform: platform,
      songId: songId,
    ),
    'song' => SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final song = section.songs[index];
        final cover = resolveSongCover(song);
        return buildSongStatus(
          context,
          song,
          (isLiked, isCurrent) => OnlineSongListItem(
            song: song,
            artistAlbumText: song.artistAlbumText,
            subtitleText: song.displaySubtitle,
            coverUrl: cover.isEmpty ? null : cover,
            isCurrent: isCurrent,
            isLiked: isLiked,
            onTap: () => onTapSong(section.songs, index),
            onLikeTap: () => onLikeSong(song),
            onMoreTap: () => onMoreSong(song),
          ),
        );
      }, childCount: section.songs.length),
    ),
    'album' => SliverGrid(
      gridDelegate: gridSpec.sliverDelegate,
      delegate: SliverChildBuilderDelegate((context, index) {
        final album = section.albums[index];
        return MediaGridCard(
          kind: MediaGridCardKind.album,
          title: album.name,
          subtitle: album.artistText,
          coverUrl: resolveCover(album.cover, album.platform),
          playCount: album.playCount,
          onTap: () => onTapAlbum(album),
        );
      }, childCount: section.albums.length),
    ),
    'playlist' => SliverGrid(
      gridDelegate: gridSpec.sliverDelegate,
      delegate: SliverChildBuilderDelegate((context, index) {
        final playlist = section.playlists[index];
        return MediaGridCard(
          kind: MediaGridCardKind.playlist,
          title: playlist.name,
          subtitle: playlist.creator,
          coverUrl: resolveCover(playlist.cover, playlist.platform),
          playCount: playlist.playCount,
          onTap: () => onTapPlaylist(playlist),
        );
      }, childCount: section.playlists.length),
    ),
    'mv' => SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridSpec.crossAxisCount,
        mainAxisSpacing: gridSpec.mainAxisSpacing,
        crossAxisSpacing: gridSpec.crossAxisSpacing,
        childAspectRatio: videoGridItemChildAspectRatio,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final mv = section.mvs[index];
        return VideoGridItem(
          title: mv.name,
          creator: mv.creator,
          duration: '${mv.duration}',
          coverUrl: resolveCover(mv.cover, mv.platform),
          playCount: mv.playCount,
          onTap: () => onTapMv(mv),
        );
      }, childCount: section.mvs.length),
    ),
    _ => const SliverToBoxAdapter(child: SizedBox.shrink()),
  };
  if (section.isEmpty) {
    return SliverToBoxAdapter(key: key, child: const SizedBox.shrink());
  }
  return SliverMainAxisGroup(
    key: key,
    slivers: [
      if (section.title.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            LayoutTokens.compactPageGutter + 2,
            0,
            LayoutTokens.compactPageGutter + 2,
            10,
          ),
          sliver: SliverToBoxAdapter(
            child: Builder(
              builder: (context) => Row(
                children: [
                  Expanded(
                    child: Text(
                      section.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (section.resourceType == 'sheet_music')
                    TextButton.icon(
                      onPressed: onMoreSheetMusic,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      label: Text(moreLabel),
                    ),
                ],
              ),
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutTokens.compactPageGutter,
        ),
        sliver: resources,
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 18)),
    ],
  );
}
