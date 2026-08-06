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

typedef HomeSongStatusBuilder =
    Widget Function(
      BuildContext context,
      SongInfo song,
      Widget Function(bool isLiked, bool isCurrent) builder,
    );

typedef HomeSelectionStatusBuilder<T> =
    Widget Function(
      BuildContext context,
      T item,
      Widget Function(bool selected) builder,
    );

// 横滑卡片保持稳定尺寸，并让紧凑屏幕露出未完整展示的末端内容。
const _homeQuickEntryHorizontalExtent = 112.0;
const _homeQuickEntryPeekExtent = 26.0;
const _homeQuickEntrySmallWidth = 320.0;
const _homeQuickEntryMobileWidth = 600.0;

double _resolveHomeQuickEntryHorizontalExtent({
  required double maxWidth,
  required AdaptiveMediaGridSpec gridSpec,
}) {
  if (maxWidth >= _homeQuickEntryMobileWidth) {
    return _homeQuickEntryHorizontalExtent;
  }

  // 极窄屏保留两张完整卡片；其余移动端沿用自适应列数，宽屏可自然展示更多卡片。
  final fullItemCount = maxWidth < _homeQuickEntrySmallWidth
      ? 2
      : gridSpec.crossAxisCount;
  final totalSpacing = gridSpec.crossAxisSpacing * fullItemCount;
  return (maxWidth - totalSpacing - _homeQuickEntryPeekExtent) / fullItemCount;
}

/// 快捷入口按至少三列计算单行容量，超过容量时由渲染层改为横滑。
AdaptiveMediaGridSpec resolveHomeQuickEntryGridSpec({
  required double maxWidth,
}) {
  return resolveAdaptiveMediaGridSpec(
    maxWidth: maxWidth,
    minItemWidth: 104,
    childAspectRatio: 1,
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
  required HomeSongStatusBuilder buildSongStatus,
  required Future<void> Function(SongInfo song) onLikeSong,
  required HomeSelectionStatusBuilder<RadioInfo> buildRadioStatus,
  required HomeSelectionStatusBuilder<HomePageEntry> buildEntryRadioStatus,
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
        buildSongStatus: buildSongStatus,
        onLikeSong: onLikeSong,
        buildRadioStatus: buildRadioStatus,
        buildEntryRadioStatus: buildEntryRadioStatus,
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
  required HomeSongStatusBuilder buildSongStatus,
  required Future<void> Function(SongInfo song) onLikeSong,
  required HomeSelectionStatusBuilder<RadioInfo> buildRadioStatus,
  required HomeSelectionStatusBuilder<HomePageEntry> buildEntryRadioStatus,
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
    Widget buildEntryCard(BuildContext context, int index) {
      final entry = section.entries[index];
      Widget buildCard(bool selected) => MediaGridCard(
        kind: MediaGridCardKind.playlist,
        title: entry.title,
        subtitle: entry.subtitle,
        coverUrl: entry.cover,
        selected: selected,
        showCenterPlayIcon: selected,
        overlayText: true,
        onTap: () => onTapEntry(entry),
      );
      if (entry.targetType != HomePageEntryTargetType.radio) {
        return buildCard(false);
      }
      return buildEntryRadioStatus(context, entry, buildCard);
    }

    if (section.entries.length > quickEntryGridSpec.crossAxisCount) {
      return <Widget>[
        SliverPadding(
          padding: horizontalPadding,
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemExtent = _resolveHomeQuickEntryHorizontalExtent(
                  maxWidth: constraints.maxWidth,
                  gridSpec: quickEntryGridSpec,
                );
                return SizedBox(
                  height: itemExtent,
                  child: ListView.separated(
                    primary: false,
                    padding: EdgeInsets.zero,
                    scrollDirection: Axis.horizontal,
                    itemCount: section.entries.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(width: quickEntryGridSpec.crossAxisSpacing),
                    itemBuilder: (context, index) => SizedBox.square(
                      dimension: itemExtent,
                      child: buildEntryCard(context, index),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ];
    }
    return <Widget>[
      SliverPadding(
        padding: horizontalPadding,
        sliver: SliverGrid(
          gridDelegate: quickEntryGridSpec.sliverDelegate,
          delegate: SliverChildBuilderDelegate(
            buildEntryCard,
            childCount: section.entries.length,
          ),
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
            return buildRadioStatus(
              context,
              radio,
              (selected) => MediaGridCard(
                kind: MediaGridCardKind.playlist,
                title: radio.name,
                subtitle: '',
                coverUrl: resolveRadioCover?.call(radio) ?? radio.cover,
                selected: selected,
                showCenterPlayIcon: selected,
                onTap: () => onTapRadio(radio),
              ),
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
        for (var index = 0; index < 8; index++) ...const <Widget>[
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
