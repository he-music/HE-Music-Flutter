import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/animated_skeleton.dart';
import '../../../../shared/widgets/video_item.dart';
import '../../../../shared/utils/cover_resolver.dart';
import '../../../../shared/utils/playlist_song_count_text.dart';
import '../../domain/entities/online_platform.dart';
import '../providers/online_providers.dart';
import '../utils/search_text_highlight.dart';
import '../widgets/online_search_song_result_item.dart';
import '../widgets/search_album_list_item.dart';
import '../widgets/search_artist_list_item.dart';
import '../widgets/search_playlist_list_item.dart';
import 'online_search_models.dart';

class OnlineSearchComprehensiveSkeleton extends StatelessWidget {
  const OnlineSearchComprehensiveSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: const <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: _ComprehensiveSkeletonSection(titleWidth: 108, itemCount: 1),
          ),
        ),
        SliverToBoxAdapter(
          child: _ComprehensiveSkeletonSection(titleWidth: 64, itemCount: 3),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 14)),
        SliverToBoxAdapter(
          child: _ComprehensiveSkeletonSection(titleWidth: 76, itemCount: 2),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

class _ComprehensiveSkeletonSection extends StatelessWidget {
  const _ComprehensiveSkeletonSection({
    required this.titleWidth,
    required this.itemCount,
  });

  final double titleWidth;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SkeletonBox(width: titleWidth, height: 18, radius: 8),
        ),
        const SizedBox(height: 8),
        ...List<Widget>.generate(
          itemCount,
          (index) => const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: _ComprehensiveSkeletonRow(),
          ),
        ),
      ],
    );
  }
}

class _ComprehensiveSkeletonRow extends StatelessWidget {
  const _ComprehensiveSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 58,
      child: Row(
        children: <Widget>[
          SkeletonBox(width: 50, height: 50, radius: 10),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SkeletonBox(width: 164, height: 15, radius: 7),
                SizedBox(height: 8),
                SkeletonBox(width: 112, height: 12, radius: 6),
              ],
            ),
          ),
          SizedBox(width: 8),
          SkeletonBox(width: 28, height: 28, radius: 14),
        ],
      ),
    );
  }
}

class OnlineSearchComprehensiveResult extends ConsumerWidget {
  const OnlineSearchComprehensiveResult({
    required this.result,
    required this.likedSongKeys,
    required this.onTapItem,
    required this.onTapSongItem,
    required this.onLikeSongItem,
    required this.onMoreSongItem,
    required this.onMoreSection,
    super.key,
  });

  final OnlineComprehensiveSearchResult result;
  final Set<String> likedSongKeys;
  final void Function(SearchType type, Map<String, dynamic> item) onTapItem;
  final ValueChanged<SongInfo> onTapSongItem;
  final Future<void> Function(SongInfo item) onLikeSongItem;
  final ValueChanged<SongInfo> onMoreSongItem;
  final ValueChanged<SearchType> onMoreSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = ref.watch(appConfigProvider).localeCode;
    final commonSections =
        <
          ({
            SearchType type,
            OnlineComprehensiveSearchSection<Map<String, dynamic>> section,
          })
        >[
          (type: SearchType.artist, section: result.artist),
          (type: SearchType.album, section: result.album),
          (type: SearchType.playlist, section: result.playlist),
          (type: SearchType.video, section: result.video),
        ];
    final sections = <Widget>[
      if (!result.song.isEmpty)
        _SectionBlock(
          type: SearchType.song,
          hasMore: result.song.hasMore,
          onMoreSection: onMoreSection,
          child: _SongSectionList(
            items: result.song.items,
            searchKeyword: result.keyword,
            likedSongKeys: likedSongKeys,
            onTapSongItem: onTapSongItem,
            onLikeSongItem: onLikeSongItem,
            onMoreSongItem: onMoreSongItem,
          ),
        ),
      for (final entry in commonSections)
        if (!entry.section.isEmpty)
          _SectionBlock(
            type: entry.type,
            hasMore: entry.section.hasMore,
            onMoreSection: onMoreSection,
            child: _CommonSectionList(
              type: entry.type,
              items: entry.section.items,
              onTapItem: onTapItem,
            ),
          ),
    ];
    final hasBestMatch = result.hasBestMatch;
    if (!hasBestMatch && sections.isEmpty) {
      return Center(
        child: Text(AppI18n.tByLocaleCode(localeCode, 'search.result.empty')),
      );
    }
    // best match 区域 + 各分类 section，统一用 CustomScrollView 滚动
    return CustomScrollView(
      slivers: <Widget>[
        // 猜你想搜区域
        if (hasBestMatch)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _BestMatchBlock(
                items: result.bestMatch,
                searchKeyword: result.keyword,
                likedSongKeys: likedSongKeys,
                onTapItem: onTapItem,
                onTapSongItem: onTapSongItem,
                onLikeSongItem: onLikeSongItem,
                onMoreSongItem: onMoreSongItem,
              ),
            ),
          ),
        // 各分类搜索结果 section
        SliverList.separated(
          itemCount: sections.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            return sections[index];
          },
        ),
        // 底部留白
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

// ============================================================
// 猜你想搜区域：primary 全宽 + 其余横向滚动卡片
// ============================================================

const _bestMatchCoverHeight = 120.0;
const _bestMatchCardWidthSquare = 120.0;
const _bestMatchCardWidthVideo = 160.0;

double _bestMatchCardWidth(SearchType type) {
  return type == SearchType.video
      ? _bestMatchCardWidthVideo
      : _bestMatchCardWidthSquare;
}

class _BestMatchBlock extends ConsumerWidget {
  const _BestMatchBlock({
    required this.items,
    required this.searchKeyword,
    required this.likedSongKeys,
    required this.onTapItem,
    required this.onTapSongItem,
    required this.onLikeSongItem,
    required this.onMoreSongItem,
  });

  final List<BestMatchRecommendItem> items;
  final String searchKeyword;
  final Set<String> likedSongKeys;
  final void Function(SearchType type, Map<String, dynamic> item) onTapItem;
  final ValueChanged<SongInfo> onTapSongItem;
  final Future<void> Function(SongInfo item) onLikeSongItem;
  final ValueChanged<SongInfo> onMoreSongItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = ref.watch(appConfigProvider).localeCode;
    // 第一项作为 primary 全宽展示，其余横向滚动
    final primary = items.first;
    final recommendations = items.skip(1).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            AppI18n.tByLocaleCode(localeCode, 'search.best_match.title'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        // primary 全宽列表项
        _BestMatchPrimaryItem(
          item: primary,
          searchKeyword: searchKeyword,
          likedSongKeys: likedSongKeys,
          onTapItem: onTapItem,
          onTapSongItem: onTapSongItem,
          onLikeSongItem: onLikeSongItem,
          onMoreSongItem: onMoreSongItem,
        ),
        // 其余推荐横向滚动
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: _bestMatchCardHeight(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: recommendations.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = recommendations[index];
                final cardWidth = _bestMatchCardWidth(
                  item.searchType ?? SearchType.song,
                );
                return SizedBox(
                  width: cardWidth,
                  child: _BestMatchCard(
                    item: item,
                    searchKeyword: searchKeyword,
                    onTap: () {
                      final type = item.searchType;
                      final data = item.data;
                      if (type == SearchType.song && data is SearchSongInfo) {
                        onTapSongItem(data.song);
                      } else if (type != null && data is Map<String, dynamic>) {
                        onTapItem(type, data);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// 卡片高度：封面高度 + 间距 + 两行文字
  double _bestMatchCardHeight(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleHeight = (textTheme.titleSmall?.fontSize ?? 14) * 1.2;
    final subtitleHeight = (textTheme.bodySmall?.fontSize ?? 12) * 1.1;
    return _bestMatchCoverHeight + 6 + titleHeight + 2 + subtitleHeight;
  }
}

// ============================================================
// Primary 全宽列表项（第一项）
// ============================================================

class _BestMatchPrimaryItem extends ConsumerWidget {
  const _BestMatchPrimaryItem({
    required this.item,
    required this.searchKeyword,
    required this.likedSongKeys,
    required this.onTapItem,
    required this.onTapSongItem,
    required this.onLikeSongItem,
    required this.onMoreSongItem,
  });

  final BestMatchRecommendItem item;
  final String searchKeyword;
  final Set<String> likedSongKeys;
  final void Function(SearchType type, Map<String, dynamic> item) onTapItem;
  final ValueChanged<SongInfo> onTapSongItem;
  final Future<void> Function(SongInfo item) onLikeSongItem;
  final ValueChanged<SongInfo> onMoreSongItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchType = item.searchType;
    if (searchType == null) {
      return const SizedBox.shrink();
    }
    final data = item.data;
    if (searchType == SearchType.song) {
      if (data is! SearchSongInfo) {
        return const SizedBox.shrink();
      }
      return OnlineSearchSongResultItem(
        item: data,
        searchKeyword: searchKeyword,
        likedSongKeys: likedSongKeys,
        onTapSong: onTapSongItem,
        onLikeSong: onLikeSongItem,
        onMoreSong: onMoreSongItem,
      );
    }
    if (data is! Map<String, dynamic>) {
      return const SizedBox.shrink();
    }
    final localeCode = ref.read(appConfigProvider).localeCode;
    final platforms =
        ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];

    final image = resolveTemplateCoverUrl(
      platforms: platforms,
      platformId: text(data['platform']),
      cover: text(data['cover']) == '-' ? '' : text(data['cover']),
      size: 300,
    );
    final title = displayTitle(searchType, data);
    final subtitle = displaySubtitle(searchType, data);

    return switch (searchType) {
      SearchType.playlist => SearchPlaylistListItem(
        title: title,
        subtitle: subtitle,
        coverUrl: image,
        songCountText: buildPlaylistSongCountText(
          count: searchPlaylistInfo(data).songCount,
          localeCode: localeCode,
        ),
        onTap: () => onTapItem(searchType, data),
      ),
      SearchType.album => SearchAlbumListItem(
        title: title,
        subtitle: subtitle,
        coverUrl: image,
        onTap: () => onTapItem(searchType, data),
      ),
      SearchType.artist => SearchArtistListItem(
        localeCode: localeCode,
        title: title,
        coverUrl: image,
        songCount: artistSongCount(data),
        albumCount: artistAlbumCount(data),
        videoCount: artistVideoCount(data),
        onTap: () => onTapItem(searchType, data),
      ),
      SearchType.video => VideoListItem(
        title: title,
        creator: subtitle == '-' ? null : subtitle,
        duration: '${searchVideoInfo(data).duration}',
        coverUrl: image,
        playCount: searchVideoInfo(data).playCount,
        onTap: () => onTapItem(searchType, data),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

// ============================================================
// 横向滚动推荐卡片（封面 + 标题 + 副标题，视频 4:3 其余 1:1）
// ============================================================

class _BestMatchCard extends ConsumerWidget {
  const _BestMatchCard({
    required this.item,
    required this.searchKeyword,
    required this.onTap,
  });

  final BestMatchRecommendItem item;
  final String searchKeyword;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchType = item.searchType;
    if (searchType == null) {
      return const SizedBox.shrink();
    }
    final data = item.data;
    final localeCode = ref.read(appConfigProvider).localeCode;
    final platforms =
        ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    late final String image;
    late final String title;
    late final String subtitle;
    List<String> matchedKeywords = const <String>[];
    if (searchType == SearchType.song && data is SearchSongInfo) {
      final song = data.song;
      final config = ref.read(appConfigProvider);
      image = resolveSongCoverUrl(
        baseUrl: config.apiBaseUrl,
        token: config.authToken ?? '',
        platforms: platforms,
        platformId: song.platform,
        songId: song.id,
        cover: song.cover,
        size: 300,
      );
      title = song.title;
      subtitle = song.artist;
      matchedKeywords = data.matchedKeywords;
    } else if (data is Map<String, dynamic>) {
      image = resolveTemplateCoverUrl(
        platforms: platforms,
        platformId: text(data['platform']),
        cover: text(data['cover']) == '-' ? '' : text(data['cover']),
        size: 300,
      );
      title = displayTitle(searchType, data);
      subtitle = _cardSubtitle(searchType, data);
    } else {
      return const SizedBox.shrink();
    }
    final isArtist = searchType == SearchType.artist;
    final fallbackIcon = switch (searchType) {
      SearchType.artist => Icons.person_rounded,
      SearchType.video => Icons.videocam_rounded,
      _ => Icons.music_note_rounded,
    };
    // 歌手是圆形不需要标签，其余显示文字标签
    final badgeText = switch (searchType) {
      SearchType.playlist => AppI18n.tByLocaleCode(
        localeCode,
        'search.type.playlist',
      ),
      SearchType.album => AppI18n.tByLocaleCode(
        localeCode,
        'search.type.album',
      ),
      SearchType.video => AppI18n.tByLocaleCode(
        localeCode,
        'search.type.video',
      ),
      SearchType.song => AppI18n.tByLocaleCode(localeCode, 'search.type.song'),
      _ => null,
    };
    final showSubtitle = subtitle.trim().isNotEmpty && subtitle != '-';
    final theme = Theme.of(context);
    final coverWidth = _bestMatchCardWidth(searchType);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: isArtist
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[
          // 封面
          _BestMatchCover(
            url: image,
            width: coverWidth,
            height: _bestMatchCoverHeight,
            isCircle: isArtist,
            fallbackIcon: fallbackIcon,
            badgeText: isArtist ? null : badgeText,
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: _highlightSpans(
                context: context,
                text: title,
                matchedKeywords: matchedKeywords,
              ),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: isArtist ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          if (showSubtitle) ...[
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: _highlightSpans(
                  context: context,
                  text: subtitle,
                  matchedKeywords: matchedKeywords,
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: isArtist ? TextAlign.center : TextAlign.start,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _cardSubtitle(SearchType type, Map<String, dynamic> data) {
    return switch (type) {
      SearchType.artist => '',
      SearchType.playlist => searchPlaylistInfo(data).creator,
      SearchType.album => _artistNamesText(searchAlbumInfo(data).artists),
      SearchType.video => searchVideoInfo(data).creator,
      _ => '',
    };
  }

  String _artistNamesText(List<SongInfoArtistInfo> artists) {
    return artists
        .map((a) => a.name.trim())
        .where((n) => n.isNotEmpty)
        .join('/');
  }

  List<InlineSpan> _highlightSpans({
    required BuildContext context,
    required String text,
    required List<String> matchedKeywords,
  }) {
    final highlightStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    return splitSearchHighlightText(
          text: text,
          matchedKeywords: matchedKeywords,
          fallbackKeyword: item.searchType == SearchType.song
              ? searchKeyword
              : '',
        )
        .map<InlineSpan>(
          (segment) => TextSpan(
            text: segment.text,
            style: segment.highlighted ? highlightStyle : null,
          ),
        )
        .toList(growable: false);
  }
}

/// 封面组件：歌手圆形，其余圆角矩形 + 可选左下角文字标签
class _BestMatchCover extends StatelessWidget {
  const _BestMatchCover({
    required this.url,
    required this.width,
    required this.height,
    required this.isCircle,
    required this.fallbackIcon,
    this.badgeText,
  });

  final String url;
  final double width;
  final double height;
  final bool isCircle;
  final IconData fallbackIcon;

  /// 左下角类型文字标签，null 则不显示
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.72,
        ),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(14),
      ),
      child: Icon(
        fallbackIcon,
        size: isCircle ? 36 : 28,
        color: theme.hintColor,
      ),
    );
    if (url.trim().isEmpty) {
      return fallback;
    }
    final image = AppNetworkImage(
      url: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      cacheWidth: 300,
      fallback: fallback,
    );
    if (isCircle) {
      return ClipOval(child: image);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: <Widget>[
          image,
          if (badgeText != null)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// 搜索结果分类 section（原有逻辑不变）
// ============================================================

class _SectionBlock extends ConsumerWidget {
  const _SectionBlock({
    required this.type,
    required this.hasMore,
    required this.onMoreSection,
    required this.child,
  });

  final SearchType type;
  final bool hasMore;
  final ValueChanged<SearchType> onMoreSection;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = ref.watch(appConfigProvider).localeCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppI18n.tByLocaleCode(localeCode, type.labelKey),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (hasMore)
                TextButton(
                  onPressed: () => onMoreSection(type),
                  child: Text(AppI18n.tByLocaleCode(localeCode, 'common.more')),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _SongSectionList extends StatelessWidget {
  const _SongSectionList({
    required this.items,
    required this.searchKeyword,
    required this.likedSongKeys,
    required this.onTapSongItem,
    required this.onLikeSongItem,
    required this.onMoreSongItem,
  });

  final List<SearchSongInfo> items;
  final String searchKeyword;
  final Set<String> likedSongKeys;
  final ValueChanged<SongInfo> onTapSongItem;
  final Future<void> Function(SongInfo item) onLikeSongItem;
  final ValueChanged<SongInfo> onMoreSongItem;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final item = items[index];
        return OnlineSearchSongResultItem(
          key: ValueKey<String>(
            'comprehensive-song-${item.song.id}|${item.song.platform}',
          ),
          item: item,
          searchKeyword: searchKeyword,
          likedSongKeys: likedSongKeys,
          onTapSong: onTapSongItem,
          onLikeSong: onLikeSongItem,
          onMoreSong: onMoreSongItem,
        );
      },
    );
  }
}

class _CommonSectionList extends ConsumerWidget {
  const _CommonSectionList({
    required this.type,
    required this.items,
    required this.onTapItem,
  });

  final SearchType type;
  final List<Map<String, dynamic>> items;
  final void Function(SearchType type, Map<String, dynamic> item) onTapItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 2),
      itemBuilder: (context, index) => _buildItem(ref, items[index]),
    );
  }

  Widget _buildItem(WidgetRef ref, Map<String, dynamic> item) {
    final localeCode = ref.read(appConfigProvider).localeCode;
    final platforms =
        ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    final image = resolveTemplateCoverUrl(
      platforms: platforms,
      platformId: text(item['platform']),
      cover: text(item['cover']) == '-' ? '' : text(item['cover']),
      size: 300,
    );
    final title = displayTitle(type, item);
    final subtitle = displaySubtitle(type, item);
    return switch (type) {
      SearchType.playlist => SearchPlaylistListItem(
        title: title,
        subtitle: subtitle,
        coverUrl: image,
        songCountText: buildPlaylistSongCountText(
          count: searchPlaylistInfo(item).songCount,
          localeCode: localeCode,
        ),
        onTap: () => onTapItem(type, item),
      ),
      SearchType.album => SearchAlbumListItem(
        title: title,
        subtitle: subtitle,
        coverUrl: image,
        onTap: () => onTapItem(type, item),
      ),
      SearchType.artist => SearchArtistListItem(
        localeCode: localeCode,
        title: title,
        coverUrl: image,
        songCount: artistSongCount(item),
        albumCount: artistAlbumCount(item),
        videoCount: artistVideoCount(item),
        onTap: () => onTapItem(type, item),
      ),
      SearchType.video => VideoListItem(
        title: title,
        creator: subtitle == '-' ? null : subtitle,
        duration: '${searchVideoInfo(item).duration}',
        coverUrl: image,
        playCount: searchVideoInfo(item).playCount,
        onTap: () => onTapItem(type, item),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
