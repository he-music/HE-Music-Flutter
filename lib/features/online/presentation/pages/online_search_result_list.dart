import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/skin/app_skin_surface.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/cover_resolver.dart';
import '../../../../shared/utils/playlist_song_count_text.dart';
import '../../../../shared/widgets/animated_skeleton.dart';
import '../../../../shared/widgets/plaza_loading_skeleton.dart';
import '../../../../shared/widgets/song_list_component.dart';
import '../../../../shared/widgets/video_item.dart';
import '../../domain/entities/online_platform.dart';
import '../providers/online_providers.dart';
import '../widgets/online_search_song_result_item.dart';
import '../widgets/search_album_list_item.dart';
import '../widgets/search_artist_list_item.dart';
import '../widgets/search_playlist_list_item.dart';
import 'online_search_models.dart';

class OnlineSearchResultList extends ConsumerStatefulWidget {
  const OnlineSearchResultList({
    required this.type,
    required this.results,
    this.songResults = const <SearchSongInfo>[],
    this.searchKeyword = '',
    required this.error,
    required this.initialLoading,
    required this.likedSongKeys,
    required this.loadingMore,
    required this.hasMore,
    required this.onTapItem,
    required this.onLikeSongItem,
    required this.onMoreSongItem,
    required this.onLoadMore,
    required this.onTapSongItem,
    super.key,
  });

  final SearchType type;
  final List<Map<String, dynamic>> results;
  final List<SearchSongInfo> songResults;
  final String searchKeyword;
  final String? error;
  final bool initialLoading;
  final Set<String> likedSongKeys;
  final bool loadingMore;
  final bool hasMore;
  final ValueChanged<Map<String, dynamic>> onTapItem;
  final Future<void> Function(SongInfo) onLikeSongItem;
  final ValueChanged<SongInfo> onMoreSongItem;
  final Future<void> Function() onLoadMore;
  final ValueChanged<SongInfo> onTapSongItem;

  @override
  ConsumerState<OnlineSearchResultList> createState() =>
      _OnlineSearchResultListState();
}

class _OnlineSearchResultListState
    extends ConsumerState<OnlineSearchResultList> {
  final ScrollController _commonScrollController = ScrollController();
  bool _loadingMoreTriggered = false;

  @override
  void initState() {
    super.initState();
    _commonScrollController.addListener(_onCommonScroll);
  }

  @override
  void didUpdateWidget(covariant OnlineSearchResultList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadingMore && !widget.loadingMore) {
      _loadingMoreTriggered = false;
    }
  }

  @override
  void dispose() {
    _commonScrollController
      ..removeListener(_onCommonScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platforms =
        ref.watch(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    final localeCode = ref.watch(appConfigProvider).localeCode;
    if (widget.error != null) {
      return Center(
        child: Text(
          widget.error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (widget.type == SearchType.song || widget.type == SearchType.lyric) {
      return SongListComponent(
        itemCount: widget.songResults.length,
        itemBuilder: (context, index) {
          final item = widget.songResults[index];
          return OnlineSearchSongResultItem(
            key: ValueKey<String>(
              'search-song-${item.song.id}|${item.song.platform}',
            ),
            item: item,
            searchKeyword: widget.searchKeyword,
            likedSongKeys: widget.likedSongKeys,
            allowFullLyric: widget.type == SearchType.lyric,
            onTapSong: widget.onTapSongItem,
            onLikeSong: widget.onLikeSongItem,
            onMoreSong: widget.onMoreSongItem,
          );
        },
        initialLoading: widget.initialLoading,
        loadingMore: widget.loadingMore,
        hasMore: widget.hasMore,
        onLoadMore: widget.onLoadMore,
      );
    }
    if (widget.initialLoading) {
      if (widget.type == SearchType.video) {
        return const PlazaVideoListSkeleton();
      }
      return _SearchResultSkeletonList(type: widget.type);
    }
    if (widget.results.isEmpty) {
      return Center(
        child: Text(AppI18n.tByLocaleCode(localeCode, 'search.result.empty')),
      );
    }
    final showFooter = widget.loadingMore || !widget.hasMore;
    return ListView.separated(
      controller: _commonScrollController,
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      itemCount: widget.results.length + (showFooter ? 1 : 0),
      separatorBuilder: (context, index) {
        if (showFooter && index == widget.results.length - 1) {
          return const SizedBox(height: 10);
        }
        return const SizedBox(height: 2);
      },
      itemBuilder: (context, index) {
        if (index >= widget.results.length) {
          return _buildFooter(context);
        }
        final item = widget.results[index];
        final image = resolveTemplateCoverUrl(
          platforms: platforms,
          platformId: text(item['platform']),
          cover: text(item['cover']) == '-' ? '' : text(item['cover']),
          size: 300,
        );
        final title = displayTitle(widget.type, item);
        final subtitle = displaySubtitle(widget.type, item);
        return switch (widget.type) {
          SearchType.playlist => SearchPlaylistListItem(
            title: title,
            subtitle: subtitle,
            coverUrl: image,
            songCountText: buildPlaylistSongCountText(
              count: searchPlaylistInfo(item).songCount,
              localeCode: localeCode,
            ),
            onTap: () => widget.onTapItem(item),
          ),
          SearchType.album => SearchAlbumListItem(
            title: title,
            subtitle: subtitle,
            coverUrl: image,
            onTap: () => widget.onTapItem(item),
          ),
          SearchType.artist => SearchArtistListItem(
            localeCode: localeCode,
            title: title,
            coverUrl: image,
            songCount: artistSongCount(item),
            albumCount: artistAlbumCount(item),
            videoCount: artistVideoCount(item),
            onTap: () => widget.onTapItem(item),
          ),
          SearchType.video => VideoListItem(
            title: title,
            creator: subtitle == '-' ? null : subtitle,
            duration: '${searchVideoInfo(item).duration}',
            coverUrl: image,
            playCount: searchVideoInfo(item).playCount,
            onTap: () => widget.onTapItem(item),
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    final localeCode = ref.read(appConfigProvider).localeCode;
    if (widget.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SkeletonBox(width: 92, height: 12, radius: 999)),
      );
    }
    if (!widget.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            AppI18n.tByLocaleCode(localeCode, 'search.result.no_more'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _onCommonScroll() {
    if (widget.type == SearchType.song ||
        widget.type == SearchType.lyric ||
        widget.loadingMore ||
        !widget.hasMore ||
        _loadingMoreTriggered) {
      return;
    }
    if (!_commonScrollController.hasClients) {
      return;
    }
    final position = _commonScrollController.position;
    if (position.pixels < position.maxScrollExtent - 120) {
      return;
    }
    _loadingMoreTriggered = true;
    widget.onLoadMore();
  }
}

class _SearchResultSkeletonList extends StatelessWidget {
  const _SearchResultSkeletonList({required this.type});

  final SearchType type;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      itemCount: 8,
      separatorBuilder: (context, index) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        return AppSkinContentSurface(
          child: switch (type) {
            SearchType.playlist => const _PlaylistSkeletonItem(),
            SearchType.album => const _AlbumSkeletonItem(),
            SearchType.artist => const _ArtistSkeletonItem(),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

class _PlaylistSkeletonItem extends StatelessWidget {
  const _PlaylistSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: <Widget>[
          SkeletonBox(width: 50, height: 50, radius: 12),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: double.infinity, height: 13, radius: 4),
                SizedBox(height: 7),
                SkeletonBox(width: 170, height: 10, radius: 4),
              ],
            ),
          ),
          SizedBox(width: 8),
          SkeletonBox(width: 16, height: 16, radius: 999),
        ],
      ),
    );
  }
}

class _AlbumSkeletonItem extends StatelessWidget {
  const _AlbumSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: <Widget>[
          SkeletonBox(width: 50, height: 50, radius: 12),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: 210, height: 13, radius: 4),
                SizedBox(height: 7),
                SkeletonBox(width: double.infinity, height: 10, radius: 4),
              ],
            ),
          ),
          SizedBox(width: 8),
          SkeletonBox(width: 16, height: 16, radius: 999),
        ],
      ),
    );
  }
}

class _ArtistSkeletonItem extends StatelessWidget {
  const _ArtistSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: <Widget>[
          SkeletonBox(width: 68, height: 68, radius: 12),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: 160, height: 16, radius: 5),
                SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 12,
                        radius: 4,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 12,
                        radius: 4,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 12,
                        radius: 4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
