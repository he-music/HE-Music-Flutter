import 'package:flutter/material.dart';

import '../../../../app/theme/skin/app_skin_surface.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/layout/adaptive_media_grid_spec.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/widgets/animated_skeleton.dart';
import '../../../../shared/widgets/artist_grid_card.dart';
import '../../../../shared/widgets/media_grid_card.dart';
import '../../../../shared/widgets/online_song_list_item.dart';
import '../../../../shared/widgets/video_item.dart';
import '../../../ranking/domain/entities/ranking_info.dart';
import '../../../ranking/presentation/widgets/ranking_cards.dart';
import '../../domain/entities/home_page_section.dart';
import '../../domain/entities/home_page_state.dart';

class HomeSectionAction {
  const HomeSectionAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

/// 快捷入口信息密度高于媒体浏览网格，手机端至少保留三列。
AdaptiveMediaGridSpec resolveHomeQuickEntryGridSpec({
  required double maxWidth,
}) {
  return resolveAdaptiveMediaGridSpec(
    maxWidth: maxWidth,
    minItemWidth: 104,
    childAspectRatio: 0.74,
    minCrossAxisCount: 3,
  );
}

List<Widget> buildHomeSectionSlivers({
  required HomeContentState state,
  required AdaptiveMediaGridSpec gridSpec,
  required AdaptiveMediaGridSpec quickEntryGridSpec,
  required String loadingText,
  required String emptyText,
  required String retryText,
  required VoidCallback onRetry,
  required HomeSectionAction? Function(HomePageSection section) sectionActionOf,
  required void Function(List<SongInfo> songs, int index) onTapSong,
  required ValueChanged<AlbumInfo> onTapAlbum,
  required ValueChanged<PlaylistInfo> onTapPlaylist,
  required ValueChanged<MvInfo> onTapMv,
  required ValueChanged<ArtistInfo> onTapArtist,
  required ValueChanged<RankingInfo> onTapRanking,
  required ValueChanged<RadioInfo> onTapRadio,
  required ValueChanged<HomePageEntry> onTapEntry,
  required ValueChanged<SongInfo> onMoreSong,
  required bool Function(SongInfo song) isSongLiked,
  required Future<void> Function(SongInfo song) onLikeSong,
  required bool Function(SongInfo song) isCurrentSong,
  required bool Function(RadioInfo radio) isRadioPlaying,
  required bool Function(HomePageEntry entry) isEntryRadioPlaying,
  String Function(SongInfo item)? resolveSongCover,
  String Function(AlbumInfo item)? resolveAlbumCover,
  String Function(PlaylistInfo item)? resolvePlaylistCover,
  String Function(MvInfo item)? resolveMvCover,
  String Function(ArtistInfo item)? resolveArtistCover,
  String Function(RadioInfo item)? resolveRadioCover,
}) {
  if (state.loading && state.sections.isEmpty) {
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutTokens.compactPageGutter,
        ),
        sliver: SliverToBoxAdapter(
          child: _HomeSectionsSkeleton(label: loadingText),
        ),
      ),
    ];
  }
  if (state.errorMessage != null && state.sections.isEmpty) {
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutTokens.compactPageGutter,
        ),
        sliver: SliverToBoxAdapter(
          child: _ErrorBlock(
            message: state.errorMessage!,
            retryText: retryText,
            onRetry: onRetry,
          ),
        ),
      ),
    ];
  }
  if (state.sections.isEmpty) {
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutTokens.compactPageGutter,
        ),
        sliver: SliverToBoxAdapter(child: _EmptyBlock(label: emptyText)),
      ),
    ];
  }

  final slivers = <Widget>[];
  for (final section in state.sections) {
    if (section.isEmpty) {
      continue;
    }
    final sectionAction = sectionActionOf(section);
    if (section.title.trim().isNotEmpty || sectionAction != null) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            LayoutTokens.compactPageGutter + 2,
            0,
            LayoutTokens.compactPageGutter + 2,
            10,
          ),
          sliver: SliverToBoxAdapter(
            child: _SectionTitle(title: section.title, action: sectionAction),
          ),
        ),
      );
    }
    slivers.addAll(
      _buildResourceSlivers(
        section: section,
        gridSpec: gridSpec,
        quickEntryGridSpec: quickEntryGridSpec,
        onTapSong: onTapSong,
        onTapAlbum: onTapAlbum,
        onTapPlaylist: onTapPlaylist,
        onTapMv: onTapMv,
        onTapArtist: onTapArtist,
        onTapRanking: onTapRanking,
        onTapRadio: onTapRadio,
        onTapEntry: onTapEntry,
        onMoreSong: onMoreSong,
        isSongLiked: isSongLiked,
        onLikeSong: onLikeSong,
        isCurrentSong: isCurrentSong,
        isRadioPlaying: isRadioPlaying,
        isEntryRadioPlaying: isEntryRadioPlaying,
        resolveSongCover: resolveSongCover,
        resolveAlbumCover: resolveAlbumCover,
        resolvePlaylistCover: resolvePlaylistCover,
        resolveMvCover: resolveMvCover,
        resolveArtistCover: resolveArtistCover,
        resolveRadioCover: resolveRadioCover,
      ),
    );
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 18)));
  }
  return slivers;
}

List<Widget> _buildResourceSlivers({
  required HomePageSection section,
  required AdaptiveMediaGridSpec gridSpec,
  required AdaptiveMediaGridSpec quickEntryGridSpec,
  required void Function(List<SongInfo> songs, int index) onTapSong,
  required ValueChanged<AlbumInfo> onTapAlbum,
  required ValueChanged<PlaylistInfo> onTapPlaylist,
  required ValueChanged<MvInfo> onTapMv,
  required ValueChanged<ArtistInfo> onTapArtist,
  required ValueChanged<RankingInfo> onTapRanking,
  required ValueChanged<RadioInfo> onTapRadio,
  required ValueChanged<HomePageEntry> onTapEntry,
  required ValueChanged<SongInfo> onMoreSong,
  required bool Function(SongInfo song) isSongLiked,
  required Future<void> Function(SongInfo song) onLikeSong,
  required bool Function(SongInfo song) isCurrentSong,
  required bool Function(RadioInfo radio) isRadioPlaying,
  required bool Function(HomePageEntry entry) isEntryRadioPlaying,
  String Function(SongInfo item)? resolveSongCover,
  String Function(AlbumInfo item)? resolveAlbumCover,
  String Function(PlaylistInfo item)? resolvePlaylistCover,
  String Function(MvInfo item)? resolveMvCover,
  String Function(ArtistInfo item)? resolveArtistCover,
  String Function(RadioInfo item)? resolveRadioCover,
}) {
  final horizontalPadding = const EdgeInsets.symmetric(
    horizontal: LayoutTokens.compactPageGutter,
  );
  if (section.sectionType == HomeSectionType.quickEntries) {
    return <Widget>[
      SliverPadding(
        padding: horizontalPadding,
        sliver: SliverGrid(
          gridDelegate: quickEntryGridSpec.sliverDelegate,
          delegate: SliverChildBuilderDelegate((context, index) {
            final entry = section.entries[index];
            final selected =
                entry.targetType == HomePageEntryTargetType.radio &&
                isEntryRadioPlaying(entry);
            return MediaGridCard(
              kind: MediaGridCardKind.playlist,
              title: entry.title,
              subtitle: entry.subtitle,
              coverUrl: entry.cover,
              selected: selected,
              showCenterPlayIcon: selected,
              onTap: () => onTapEntry(entry),
            );
          }, childCount: section.entries.length),
        ),
      ),
    ];
  }
  final resourceType = section.resourceType;
  if (resourceType == null) {
    return const <Widget>[];
  }
  return switch (resourceType) {
    HomeResourceType.song => <Widget>[
      SliverPadding(
        padding: horizontalPadding,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final song = section.songs[index];
            final cover = resolveSongCover?.call(song) ?? song.cover;
            return OnlineSongListItem(
              song: song,
              artistAlbumText: song.artistAlbumText,
              subtitleText: song.displaySubtitle,
              coverUrl: cover.isEmpty ? null : cover,
              isCurrent: isCurrentSong(song),
              isLiked: isSongLiked(song),
              onTap: () => onTapSong(section.songs, index),
              onLikeTap: () => onLikeSong(song),
              onMoreTap: () => onMoreSong(song),
            );
          }, childCount: section.songs.length),
        ),
      ),
    ],
    HomeResourceType.album => <Widget>[
      SliverPadding(
        padding: horizontalPadding,
        sliver: SliverGrid(
          gridDelegate: gridSpec.sliverDelegate,
          delegate: SliverChildBuilderDelegate((context, index) {
            final album = section.albums[index];
            return MediaGridCard(
              kind: MediaGridCardKind.album,
              title: album.name,
              subtitle: album.artistText,
              coverUrl: resolveAlbumCover?.call(album) ?? album.cover,
              playCount: album.playCount,
              onTap: () => onTapAlbum(album),
            );
          }, childCount: section.albums.length),
        ),
      ),
    ],
    HomeResourceType.playlist => <Widget>[
      SliverPadding(
        padding: horizontalPadding,
        sliver: SliverGrid(
          gridDelegate: gridSpec.sliverDelegate,
          delegate: SliverChildBuilderDelegate((context, index) {
            final playlist = section.playlists[index];
            return MediaGridCard(
              kind: MediaGridCardKind.playlist,
              title: playlist.name,
              subtitle: playlist.creator,
              coverUrl: resolvePlaylistCover?.call(playlist) ?? playlist.cover,
              playCount: playlist.playCount,
              onTap: () => onTapPlaylist(playlist),
            );
          }, childCount: section.playlists.length),
        ),
      ),
    ],
    HomeResourceType.mv => <Widget>[
      SliverPadding(
        padding: horizontalPadding,
        sliver: SliverGrid(
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
              coverUrl: resolveMvCover?.call(mv) ?? mv.cover,
              playCount: mv.playCount,
              onTap: () => onTapMv(mv),
            );
          }, childCount: section.mvs.length),
        ),
      ),
    ],
    HomeResourceType.artist => <Widget>[
      SliverPadding(
        padding: horizontalPadding,
        sliver: SliverGrid(
          gridDelegate: gridSpec.sliverDelegate,
          delegate: SliverChildBuilderDelegate((context, index) {
            final artist = section.artists[index];
            return ArtistGridCard(
              artist: artist,
              coverUrl: resolveArtistCover?.call(artist),
              onTap: () => onTapArtist(artist),
            );
          }, childCount: section.artists.length),
        ),
      ),
    ],
    HomeResourceType.ranking => <Widget>[
      SliverPadding(
        padding: horizontalPadding,
        sliver: SliverToBoxAdapter(
          child: RankingCards(rankings: section.rankings, onTap: onTapRanking),
        ),
      ),
    ],
    HomeResourceType.radio => <Widget>[
      SliverPadding(
        padding: horizontalPadding,
        sliver: SliverGrid(
          gridDelegate: gridSpec.sliverDelegate,
          delegate: SliverChildBuilderDelegate((context, index) {
            final radio = section.radios[index];
            final selected = isRadioPlaying(radio);
            return MediaGridCard(
              kind: MediaGridCardKind.playlist,
              title: radio.name,
              subtitle: '',
              coverUrl: resolveRadioCover?.call(radio) ?? radio.cover,
              selected: selected,
              showCenterPlayIcon: selected,
              onTap: () => onTapRadio(radio),
            );
          }, childCount: section.radios.length),
        ),
      ),
    ],
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});

  final String title;
  final HomeSectionAction? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (action != null)
          TextButton.icon(
            onPressed: action!.onTap,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: Text(action!.label),
          ),
      ],
    );
  }
}

class _HomeSectionsSkeleton extends StatelessWidget {
  const _HomeSectionsSkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(label: label, child: const SizedBox.shrink()),
        const SkeletonBox(width: 96, height: 20, radius: 8),
        const SizedBox(height: 12),
        for (var index = 0; index < 4; index++) ...const <Widget>[
          AppSkinContentSurface(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  SkeletonBox(width: 56, height: 56, radius: 8),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SkeletonBox(
                          width: double.infinity,
                          height: 14,
                          radius: 7,
                        ),
                        SizedBox(height: 8),
                        SkeletonBox(width: 168, height: 12, radius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(label)),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.message,
    required this.retryText,
    required this.onRetry,
  });

  final String message;
  final String retryText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(message)),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: onRetry, child: Text(retryText)),
        ],
      ),
    );
  }
}
