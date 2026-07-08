import 'package:flutter/material.dart';

import '../../../../app/config/app_config_state.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/layout/adaptive_media_grid_spec.dart';
import '../../../../shared/widgets/animated_skeleton.dart';
import '../../../../shared/widgets/media_grid_card.dart';
import '../../../../shared/widgets/online_song_list_item.dart';
import '../../../../shared/widgets/plaza_loading_skeleton.dart';
import '../../../../shared/widgets/video_item.dart';
import '../../domain/entities/home_discover_item.dart';
import '../../domain/entities/home_discover_section.dart';
import '../../domain/entities/home_discover_state.dart';

class DiscoverSectionAction {
  const DiscoverSectionAction({
    required this.label,
    required this.onTap,
    this.icon = Icons.chevron_right_rounded,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class DiscoverSections extends StatelessWidget {
  const DiscoverSections({
    required this.loadingText,
    required this.emptyText,
    required this.retryText,
    required this.titleOf,
    required this.state,
    required this.onRetry,
    required this.onTapSong,
    required this.onTapAlbum,
    required this.onTapPlaylist,
    required this.onTapVideo,
    required this.onMoreSong,
    required this.isSongLiked,
    required this.onLikeSong,
    required this.isCurrentSong,
    required this.config,
    required this.sectionActionOf,
    this.resolveSongCover,
    super.key,
  });

  final String loadingText;
  final String emptyText;
  final String retryText;
  final String Function(HomeDiscoverSection) titleOf;
  final HomeDiscoverState state;
  final VoidCallback onRetry;
  final void Function(List<SongInfo> songs, int index) onTapSong;
  final ValueChanged<AlbumInfo> onTapAlbum;
  final ValueChanged<PlaylistInfo> onTapPlaylist;
  final ValueChanged<MvInfo> onTapVideo;
  final ValueChanged<SongInfo> onMoreSong;
  final bool Function(SongInfo song) isSongLiked;
  final Future<void> Function(SongInfo song) onLikeSong;
  final bool Function(SongInfo song) isCurrentSong;
  final AppConfigState config;
  final DiscoverSectionAction? Function(HomeDiscoverSection section)
  sectionActionOf;
  final String Function(SongInfo item)? resolveSongCover;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const _DiscoverLoadingSkeleton();
    }
    if (state.errorMessage != null) {
      return _ErrorBlock(
        message: state.errorMessage!,
        retryText: retryText,
        onRetry: onRetry,
      );
    }
    if (state.sections.every((section) => section.isEmpty)) {
      return _EmptyBlock(label: emptyText);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: state.sections
          .map((section) {
            return _SectionBlock(
              title: titleOf(section),
              action: sectionActionOf(section),
              section: section,
              onTapSong: onTapSong,
              onTapAlbum: onTapAlbum,
              onTapPlaylist: onTapPlaylist,
              onTapVideo: onTapVideo,
              onMoreSong: onMoreSong,
              isSongLiked: isSongLiked,
              onLikeSong: onLikeSong,
              isCurrentSong: isCurrentSong,
              config: config,
              resolveSongCover: resolveSongCover,
            );
          })
          .toList(growable: false),
    );
  }
}

List<Widget> buildDiscoverSectionSlivers({
  required String loadingText,
  required String emptyText,
  required String retryText,
  required String Function(HomeDiscoverSection) titleOf,
  required HomeDiscoverState state,
  required AdaptiveMediaGridSpec gridSpec,
  required VoidCallback onRetry,
  required void Function(List<SongInfo> songs, int index) onTapSong,
  required ValueChanged<AlbumInfo> onTapAlbum,
  required ValueChanged<PlaylistInfo> onTapPlaylist,
  required ValueChanged<MvInfo> onTapVideo,
  required ValueChanged<SongInfo> onMoreSong,
  required bool Function(SongInfo song) isSongLiked,
  required Future<void> Function(SongInfo song) onLikeSong,
  required bool Function(SongInfo song) isCurrentSong,
  required AppConfigState config,
  required DiscoverSectionAction? Function(HomeDiscoverSection section)
  sectionActionOf,
  String Function(SongInfo item)? resolveSongCover,
  String Function(AlbumInfo item)? resolveAlbumCover,
  String Function(PlaylistInfo item)? resolvePlaylistCover,
}) {
  if (state.loading) {
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutTokens.compactPageGutter,
        ),
        sliver: const SliverToBoxAdapter(child: _DiscoverLoadingSkeleton()),
      ),
    ];
  }
  if (state.errorMessage != null) {
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
  if (state.sections.every((section) => section.isEmpty)) {
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
    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          LayoutTokens.compactPageGutter + 2,
          0,
          LayoutTokens.compactPageGutter + 2,
          10,
        ),
        sliver: SliverToBoxAdapter(
          child: _SectionTitle(
            title: titleOf(section),
            action: sectionActionOf(section),
          ),
        ),
      ),
    );
    slivers.addAll(
      _buildSectionSlivers(
        section: section,
        gridSpec: gridSpec,
        onTapSong: onTapSong,
        onTapAlbum: onTapAlbum,
        onTapPlaylist: onTapPlaylist,
        onTapVideo: onTapVideo,
        onMoreSong: onMoreSong,
        isSongLiked: isSongLiked,
        onLikeSong: onLikeSong,
        isCurrentSong: isCurrentSong,
        config: config,
        resolveSongCover: resolveSongCover,
        resolveAlbumCover: resolveAlbumCover,
        resolvePlaylistCover: resolvePlaylistCover,
      ),
    );
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 18)));
  }
  return slivers;
}

List<Widget> _buildSectionSlivers({
  required HomeDiscoverSection section,
  required AdaptiveMediaGridSpec gridSpec,
  required void Function(List<SongInfo> songs, int index) onTapSong,
  required ValueChanged<AlbumInfo> onTapAlbum,
  required ValueChanged<PlaylistInfo> onTapPlaylist,
  required ValueChanged<MvInfo> onTapVideo,
  required ValueChanged<SongInfo> onMoreSong,
  required bool Function(SongInfo song) isSongLiked,
  required Future<void> Function(SongInfo song) onLikeSong,
  required bool Function(SongInfo song) isCurrentSong,
  required AppConfigState config,
  String Function(SongInfo item)? resolveSongCover,
  String Function(AlbumInfo item)? resolveAlbumCover,
  String Function(PlaylistInfo item)? resolvePlaylistCover,
}) {
  return switch (section.type) {
    HomeDiscoverItemType.song => <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutTokens.compactPageGutter,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = section.songs[index];
            return _DiscoverSongItem(
              index: index,
              song: item,
              songs: section.songs,
              onTapSong: onTapSong,
              onMoreSong: onMoreSong,
              isSongLiked: isSongLiked,
              onLikeSong: onLikeSong,
              isCurrentSong: isCurrentSong,
              resolveSongCover: resolveSongCover,
            );
          }, childCount: section.songs.length),
        ),
      ),
    ],
    HomeDiscoverItemType.album || HomeDiscoverItemType.playlist => <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutTokens.compactPageGutter,
        ),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final items = section.type == HomeDiscoverItemType.album
                  ? section.albums
                  : section.playlists;
              if (section.type == HomeDiscoverItemType.album) {
                final item = items[index] as AlbumInfo;
                return _DiscoverGridCard(
                  type: section.type,
                  title: item.name,
                  subtitle: item.artistText,
                  coverUrl: resolveAlbumCover?.call(item) ?? item.cover,
                  playCount: item.playCount,
                  onTap: () => onTapAlbum(item),
                );
              }
              final item = items[index] as PlaylistInfo;
              return _DiscoverGridCard(
                type: section.type,
                title: item.name,
                subtitle: item.creator,
                coverUrl: resolvePlaylistCover?.call(item) ?? item.cover,
                playCount: item.playCount,
                onTap: () => onTapPlaylist(item),
              );
            },
            childCount: section.type == HomeDiscoverItemType.album
                ? section.albums.length
                : section.playlists.length,
          ),
          gridDelegate: gridSpec.sliverDelegate,
        ),
      ),
    ],
    HomeDiscoverItemType.video => <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutTokens.compactPageGutter,
        ),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = section.videos[index];
            return VideoGridItem(
              title: item.name,
              creator: item.creator,
              duration: '${item.duration}',
              coverUrl: item.cover,
              playCount: item.playCount,
              onTap: () => onTapVideo(item),
            );
          }, childCount: section.videos.length),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSpec.crossAxisCount,
            mainAxisSpacing: gridSpec.mainAxisSpacing,
            crossAxisSpacing: gridSpec.crossAxisSpacing,
            childAspectRatio: videoGridItemChildAspectRatio,
          ),
        ),
      ),
    ],
  };
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.action,
    required this.section,
    required this.onTapSong,
    required this.onTapAlbum,
    required this.onTapPlaylist,
    required this.onTapVideo,
    required this.onMoreSong,
    required this.isSongLiked,
    required this.onLikeSong,
    required this.isCurrentSong,
    required this.config,
    this.resolveSongCover,
  });

  final String title;
  final DiscoverSectionAction? action;
  final HomeDiscoverSection section;
  final void Function(List<SongInfo> songs, int index) onTapSong;
  final ValueChanged<AlbumInfo> onTapAlbum;
  final ValueChanged<PlaylistInfo> onTapPlaylist;
  final ValueChanged<MvInfo> onTapVideo;
  final ValueChanged<SongInfo> onMoreSong;
  final bool Function(SongInfo song) isSongLiked;
  final Future<void> Function(SongInfo song) onLikeSong;
  final bool Function(SongInfo song) isCurrentSong;
  final AppConfigState config;
  final String Function(SongInfo item)? resolveSongCover;

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
            child: _SectionTitle(title: title, action: action),
          ),
          _buildSectionContent(context: context),
        ],
      ),
    );
  }

  Widget _buildSectionContent({required BuildContext context}) {
    return switch (section.type) {
      HomeDiscoverItemType.song => Column(
        children: section.songs
            .asMap()
            .entries
            .map((entry) => _buildSongItem(context, entry.key, entry.value))
            .toList(growable: false),
      ),
      HomeDiscoverItemType.album ||
      HomeDiscoverItemType.playlist => LayoutBuilder(
        builder: (context, constraints) {
          final spec = resolveAdaptiveMediaGridSpec(
            maxWidth: constraints.maxWidth,
          );
          final albumItems = section.albums;
          final playlistItems = section.playlists;
          return Wrap(
            spacing: spec.crossAxisSpacing,
            runSpacing: spec.mainAxisSpacing,
            children:
                (section.type == HomeDiscoverItemType.album
                        ? albumItems.map(
                            (item) => SizedBox(
                              width: spec.itemWidth,
                              child: _DiscoverGridCard(
                                type: section.type,
                                title: item.name,
                                subtitle: item.artistText,
                                coverUrl: item.cover,
                                playCount: item.playCount,
                                onTap: () => onTapAlbum(item),
                              ),
                            ),
                          )
                        : playlistItems.map(
                            (item) => SizedBox(
                              width: spec.itemWidth,
                              child: _DiscoverGridCard(
                                type: section.type,
                                title: item.name,
                                subtitle: item.creator,
                                coverUrl: item.cover,
                                playCount: item.playCount,
                                onTap: () => onTapPlaylist(item),
                              ),
                            ),
                          ))
                    .toList(growable: false),
          );
        },
      ),
      HomeDiscoverItemType.video => LayoutBuilder(
        builder: (context, constraints) {
          final spec = resolveAdaptiveMediaGridSpec(
            maxWidth: constraints.maxWidth,
          );
          return Wrap(
            spacing: spec.crossAxisSpacing,
            runSpacing: spec.mainAxisSpacing,
            children: section.videos
                .map(
                  (item) => SizedBox(
                    width: spec.itemWidth,
                    child: VideoGridItem(
                      title: item.name,
                      creator: item.creator,
                      duration: '${item.duration}',
                      coverUrl: item.cover,
                      playCount: item.playCount,
                      onTap: () => onTapVideo(item),
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    };
  }

  Widget _buildSongItem(BuildContext context, int index, SongInfo item) {
    return _DiscoverSongItem(
      index: index,
      song: item,
      songs: section.songs,
      onTapSong: onTapSong,
      onMoreSong: onMoreSong,
      isSongLiked: isSongLiked,
      onLikeSong: onLikeSong,
      isCurrentSong: isCurrentSong,
      resolveSongCover: resolveSongCover,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});

  final String title;
  final DiscoverSectionAction? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: action!.onTap,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  action!.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(action!.icon, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}

class _DiscoverSongItem extends StatelessWidget {
  const _DiscoverSongItem({
    required this.index,
    required this.song,
    required this.songs,
    required this.onTapSong,
    required this.onMoreSong,
    required this.isSongLiked,
    required this.onLikeSong,
    required this.isCurrentSong,
    this.resolveSongCover,
  });

  final int index;
  final SongInfo song;
  final List<SongInfo> songs;
  final void Function(List<SongInfo> songs, int index) onTapSong;
  final ValueChanged<SongInfo> onMoreSong;
  final bool Function(SongInfo song) isSongLiked;
  final Future<void> Function(SongInfo song) onLikeSong;
  final bool Function(SongInfo song) isCurrentSong;
  final String Function(SongInfo item)? resolveSongCover;

  @override
  Widget build(BuildContext context) {
    final resolvedCover = resolveSongCover?.call(song) ?? song.cover;
    return OnlineSongListItem(
      song: song,
      artistAlbumText: song.artistAlbumText,
      subtitleText: song.displaySubtitle,
      coverUrl: resolvedCover.isEmpty ? null : resolvedCover,
      isCurrent: isCurrentSong(song),
      isLiked: isSongLiked(song),
      onTap: () => onTapSong(songs, index),
      onLikeTap: () => onLikeSong(song),
      onMoreTap: () => onMoreSong(song),
    );
  }
}

class _DiscoverGridCard extends StatelessWidget {
  const _DiscoverGridCard({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    this.playCount,
    required this.onTap,
  });

  final HomeDiscoverItemType type;
  final String title;
  final String subtitle;
  final String coverUrl;
  final String? playCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAlbum = type == HomeDiscoverItemType.album;
    return MediaGridCard(
      kind: isAlbum ? MediaGridCardKind.album : MediaGridCardKind.playlist,
      title: title,
      subtitle: subtitle,
      coverUrl: coverUrl,
      playCount: playCount,
      onTap: onTap,
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
      child: Text(label),
    );
  }
}

class _DiscoverLoadingSkeleton extends StatelessWidget {
  const _DiscoverLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SongSectionSkeleton(),
        SizedBox(height: 18),
        _GridSectionSkeleton(),
        SizedBox(height: 18),
        _GridSectionSkeleton(),
        SizedBox(height: 18),
        _VideoSectionSkeleton(),
      ],
    );
  }
}

class _SectionTitleSkeleton extends StatelessWidget {
  const _SectionTitleSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SectionTitleSkeleton();
  }
}

class _SongSectionSkeleton extends StatelessWidget {
  const _SongSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        _SectionTitleSkeleton(),
        _SongRowSkeleton(),
        _SongRowSkeleton(),
        _SongRowSkeleton(),
        _SongRowSkeleton(),
      ],
    );
  }
}

class _SongRowSkeleton extends StatelessWidget {
  const _SongRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: const <Widget>[
          SkeletonBox(width: 56, height: 56, radius: 16),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: double.infinity, height: 14, radius: 7),
                SizedBox(height: 8),
                SkeletonBox(width: 168, height: 12, radius: 6),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonBox(width: 18, height: 18, radius: 9),
        ],
      ),
    );
  }
}

class _GridSectionSkeleton extends StatelessWidget {
  const _GridSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitleSkeleton(),
        LayoutBuilder(
          builder: (context, constraints) {
            final spec = resolveAdaptiveMediaGridSpec(
              maxWidth: constraints.maxWidth,
            );
            return Wrap(
              spacing: spec.crossAxisSpacing,
              runSpacing: spec.mainAxisSpacing,
              children: List<Widget>.generate(
                spec.crossAxisCount * 2,
                (_) => SizedBox(
                  width: spec.itemWidth,
                  child: const GridCardSkeleton(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _VideoSectionSkeleton extends StatelessWidget {
  const _VideoSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitleSkeleton(),
        LayoutBuilder(
          builder: (context, constraints) {
            final spec = resolveAdaptiveMediaGridSpec(
              maxWidth: constraints.maxWidth,
            );
            return Wrap(
              spacing: spec.crossAxisSpacing,
              runSpacing: spec.mainAxisSpacing,
              children: List<Widget>.generate(
                spec.crossAxisCount * 2,
                (_) => SizedBox(
                  width: spec.itemWidth,
                  child: const VideoGridCardSkeleton(),
                ),
              ),
            );
          },
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
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
