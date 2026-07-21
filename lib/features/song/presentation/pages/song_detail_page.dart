import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../../shared/layout/adaptive_media_grid_spec.dart';
import '../../../../shared/helpers/album_id_helper.dart';
import '../../../../shared/helpers/current_track_helper.dart';
import '../../../../shared/helpers/detail_song_action_handler.dart';
import '../../../../shared/helpers/platform_label_helper.dart';
import '../../../../shared/helpers/song_artist_navigation_helper.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/compact_number_formatter.dart';
import '../../../../shared/utils/favorite_song_key.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/media_grid_card.dart';
import '../../../../shared/widgets/online_song_list_item.dart';
import '../../../../shared/widgets/video_item.dart';
import '../../../my/presentation/providers/favorite_song_status_providers.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../player/domain/entities/player_queue_source.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/song_detail_content.dart';
import '../../domain/entities/song_detail_relations.dart';
import '../../domain/entities/song_detail_request.dart';
import '../../domain/entities/song_detail_state.dart';
import '../providers/song_detail_providers.dart';

class SongDetailPage extends ConsumerStatefulWidget {
  const SongDetailPage({
    required this.id,
    required this.platform,
    required this.title,
    super.key,
  });

  final String id;
  final String platform;
  final String title;

  @override
  ConsumerState<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends ConsumerState<SongDetailPage> {
  late final SongDetailRequest _request;
  late final DetailSongActionHandler _songActions;

  @override
  void initState() {
    super.initState();
    _request = SongDetailRequest(
      id: widget.id,
      platform: widget.platform,
      title: widget.title,
    );
    _songActions = DetailSongActionHandler(
      ref: ref,
      queueSource: PlayerQueueSource(
        routePath: AppRoutes.songDetail,
        queryParameters: <String, String>{
          'id': widget.id,
          'platform': widget.platform,
          'title': widget.title,
        },
        title: widget.title,
      ),
    );
    Future.microtask(
      () => ref
          .read(songDetailControllerProvider(_request.cacheKey).notifier)
          .initialize(_request),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = songDetailControllerProvider(_request.cacheKey);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final content = state.content;

    if (content == null) {
      if (state.loading) {
        return DetailPageShell(child: DetailLoadingBody(title: widget.title));
      }
      return DetailPageShell(
        child: DetailErrorBody(
          message:
              state.errorMessage ??
              AppI18n.t(ref.read(appConfigProvider), 'detail.no_song_content'),
          onRetry: () => controller.retry(_request),
        ),
      );
    }

    return DetailPageShell(
      child: _buildBody(context: context, state: state, content: content),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required SongDetailState state,
    required SongDetailContent content,
  }) {
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);
    final song = content.song;
    final playerState = ref.watch(playerControllerProvider);
    final currentTrack = ref.watch(
      playerControllerProvider.select((player) => player.currentTrack),
    );
    final platforms =
        ref.watch(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    final coverUrl = _songActions.resolveCoverUrl(song);
    final publishDate = _formatPublishDate(content.publishTime);
    final isFavorited = ref.watch(
      favoriteSongStatusProvider.select(
        (favorite) => favorite.songKeys.contains(
          buildFavoriteSongKey(
            songId: song.id,
            platform: _songActions.resolvePlatformId(song),
          ),
        ),
      ),
    );
    final isCurrentSong = isCurrentSongTrack(currentTrack, song);
    final showPauseAction = isCurrentSong && playerState.isPlaying;
    final morePlayActionLabel = AppI18n.t(
      config,
      showPauseAction ? 'player.action.pause' : 'song.action.play',
    );
    final onPrimaryPlay = isCurrentSong
        ? () => ref.read(playerControllerProvider.notifier).togglePlayPause()
        : () => _songActions.playSongNow(song);

    const useWideLayout = false;
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _SongHeroCard(
                key: const ValueKey<String>('song-detail-header-compact'),
                config: config,
                useWideLayout: useWideLayout,
                title: song.title.trim().isEmpty ? widget.title : song.title,
                coverUrl: coverUrl,
                platformLabel: resolvePlatformLabel(
                  song.platform.isEmpty ? widget.platform : song.platform,
                  platforms: platforms,
                ),
                publishTime: publishDate.isEmpty ? '-' : publishDate,
                language: content.language.trim().isEmpty
                    ? '-'
                    : content.language,
                duration: formatDurationSecondsLabel('${song.duration}'),
                artistLabel: song.artist,
                albumLabel: (song.album?.name.trim().isEmpty ?? true)
                    ? '-'
                    : song.album!.name.trim(),
                isFavorited: isFavorited,
                showPauseAction: showPauseAction,
                onBack: () => context.appPopOrGo(),
                onPlay: onPrimaryPlay,
                onPlayNext: () => _songActions.playNextSong(song),
                onToggleFavorite: () =>
                    _toggleSongFavorite(isFavorited, song: song),
                onMore: (anchorContext) => _songActions.showSongActions(
                  context: anchorContext,
                  song: song,
                  coverUrl: coverUrl,
                  playActionLabel: morePlayActionLabel,
                  onPlay: onPrimaryPlay,
                  anchorContext: anchorContext,
                  includeViewDetail: false,
                  forceBottomSheet: true,
                ),
                onTapArtist: song.artists.isEmpty
                    ? null
                    : () => unawaited(
                        openSongArtistSelection(
                          context: context,
                          platformId: _songActions.resolvePlatformId(song),
                          artists: song.artists,
                          onError: (message) =>
                              AppMessageService.showError(message),
                        ),
                      ),
                onTapAlbum: hasValidAlbumId(song.album?.id ?? '')
                    ? () => context.push(
                        Uri(
                          path: AppRoutes.albumDetail,
                          queryParameters: <String, String>{
                            'id': song.album!.id,
                            'platform': _songActions.resolvePlatformId(song),
                            'title': song.album!.name,
                          },
                        ).toString(),
                      )
                    : null,
              ),
            ),
          ),
          ..._buildRelationSlivers(
            context: context,
            config: config,
            theme: theme,
            currentTrack: currentTrack,
            relations: state.relations,
            relationsLoading: state.relationsLoading,
            relationsErrorMessage: state.relationsErrorMessage,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<Widget> _buildRelationSlivers({
    required BuildContext context,
    required AppConfigState config,
    required ThemeData theme,
    required PlayerTrack? currentTrack,
    required SongDetailRelations? relations,
    required bool relationsLoading,
    required String? relationsErrorMessage,
  }) {
    final data = relations ?? const SongDetailRelations();
    return <Widget>[
      if (relationsErrorMessage != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              AppI18n.t(config, 'song.detail.relations_failed'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ),
      if (relationsLoading && relations == null)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: LinearProgressIndicator(),
          ),
        ),
      if (data.similarSongs.isNotEmpty)
        ..._buildSongSectionSlivers(
          title: AppI18n.t(config, 'song.detail.section.similar_songs'),
          songs: data.similarSongs,
          currentTrack: currentTrack,
        ),
      if (data.otherVersionSongs.isNotEmpty)
        ..._buildSongSectionSlivers(
          title: AppI18n.t(config, 'song.detail.section.other_versions'),
          songs: data.otherVersionSongs,
          currentTrack: currentTrack,
        ),
      if (data.relatedPlaylists.isNotEmpty)
        SliverToBoxAdapter(
          child: _PlaylistSection(
            title: AppI18n.t(config, 'song.detail.section.related_playlists'),
            playlists: data.relatedPlaylists,
          ),
        ),
      if (data.relatedMvs.isNotEmpty)
        ..._buildVideoSectionSlivers(
          title: AppI18n.t(config, 'song.detail.section.related_videos'),
          videos: data.relatedMvs,
        ),
    ];
  }

  Future<void> _toggleSongFavorite(
    bool isFavorited, {
    required SongInfo song,
  }) async {
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .toggleSongFavorite(
            songId: song.id,
            platform: _songActions.resolvePlatformId(song),
            like: !isFavorited,
          );
    } catch (error) {
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(
              ref.read(appConfigProvider),
              'detail.favorite.song_failed',
            ),
      );
    }
  }

  String _formatPublishDate(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return '';
    }
    final timestamp = int.tryParse(normalized);
    DateTime? date;
    if (timestamp != null) {
      final milliseconds = timestamp > 100000000000
          ? timestamp
          : timestamp * 1000;
      date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    } else {
      date = DateTime.tryParse(normalized);
    }
    if (date == null) {
      return normalized;
    }
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// 歌曲列表区域，使用 SliverList.builder 懒加载
  List<Widget> _buildSongSectionSlivers({
    required String title,
    required List<SongInfo> songs,
    required PlayerTrack? currentTrack,
  }) {
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        sliver: SliverMainAxisGroup(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _SectionTitle(title: title)),
            SliverList.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                final coverUrl = _songActions.resolveCoverUrl(song);
                return OnlineSongListItem(
                  song: song,
                  coverUrl: coverUrl.isEmpty ? null : coverUrl,
                  subtitleText: song.displaySubtitle,
                  isCurrent: isCurrentSongTrack(currentTrack, song),
                  isLiked: ref.watch(
                    favoriteSongStatusProvider.select(
                      (favorite) => favorite.songKeys.contains(
                        buildFavoriteSongKey(
                          songId: song.id,
                          platform: _songActions.resolvePlatformId(song),
                        ),
                      ),
                    ),
                  ),
                  onTap: () =>
                      _songActions.playAll(context, songs, startIndex: index),
                  onLikeTap: () => _songActions.toggleSongFavorite(song),
                  onMoreTap: () => _songActions.showSongActions(
                    context: context,
                    song: song,
                    coverUrl: coverUrl,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ];
  }

  /// 相关视频使用发现型网格，便于一行展示多个视频。
  List<Widget> _buildVideoSectionSlivers({
    required String title,
    required List<MvInfo> videos,
  }) {
    const gridSpec = AdaptiveMediaGridSpec(
      crossAxisCount: 2,
      itemWidth: 0,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: videoGridItemChildAspectRatio,
    );
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        sliver: SliverMainAxisGroup(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _SectionTitle(title: title)),
            SliverGrid.builder(
              itemCount: videos.length,
              gridDelegate: gridSpec.sliverDelegate,
              itemBuilder: (context, index) {
                final video = videos[index];
                return VideoGridItem(
                  title: video.name,
                  creator: video.creator,
                  duration: '${video.duration}',
                  coverUrl: video.cover,
                  playCount: video.playCount,
                  onTap: () => context.push(
                    Uri(
                      path: AppRoutes.videoDetail,
                      queryParameters: <String, String>{
                        'id': video.id,
                        'platform': video.platform,
                        'title': video.name,
                      },
                    ).toString(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ];
  }
}

class _SongHeroCard extends StatelessWidget {
  const _SongHeroCard({
    required this.config,
    required this.useWideLayout,
    required this.title,
    required this.coverUrl,
    required this.platformLabel,
    required this.publishTime,
    required this.language,
    required this.duration,
    required this.artistLabel,
    required this.albumLabel,
    required this.isFavorited,
    required this.showPauseAction,
    required this.onBack,
    required this.onPlay,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onMore,
    this.onTapArtist,
    this.onTapAlbum,
    super.key,
  });

  final AppConfigState config;
  final bool useWideLayout;
  final String title;
  final String coverUrl;
  final String platformLabel;
  final String publishTime;
  final String language;
  final String duration;
  final String artistLabel;
  final String albumLabel;
  final bool isFavorited;
  final bool showPauseAction;
  final VoidCallback onBack;
  final VoidCallback onPlay;
  final VoidCallback onPlayNext;
  final VoidCallback onToggleFavorite;
  final ValueChanged<BuildContext> onMore;
  final VoidCallback? onTapArtist;
  final VoidCallback? onTapAlbum;

  @override
  Widget build(BuildContext context) {
    final meta = <_MetaItem>[
      _MetaItem(
        label: AppI18n.t(config, 'player.meta.artist'),
        value: artistLabel.isEmpty ? '-' : artistLabel,
        onTap: onTapArtist,
      ),
      _MetaItem(
        label: AppI18n.t(config, 'player.meta.album'),
        value: albumLabel.isEmpty ? '-' : albumLabel,
        onTap: onTapAlbum,
      ),
      _MetaItem(
        label: AppI18n.t(config, 'song.detail.meta.platform'),
        value: platformLabel.isEmpty ? '-' : platformLabel,
      ),
      _MetaItem(
        label: AppI18n.t(config, 'song.detail.meta.publish_time'),
        value: publishTime,
      ),
      _MetaItem(
        label: AppI18n.t(config, 'song.detail.meta.language'),
        value: language,
      ),
      _MetaItem(
        label: AppI18n.t(config, 'song.detail.meta.duration'),
        value: duration,
      ),
    ];
    final titleSection = _HeroInfo(
      config: config,
      title: title,
      artistLabel: artistLabel,
      albumLabel: albumLabel,
      onTapArtist: onTapArtist,
      onTapAlbum: onTapAlbum,
      compact: true,
    );
    final actionSection = _HeroActions(
      key: const ValueKey<String>('song-detail-actions-compact'),
      config: config,
      isFavorited: isFavorited,
      showPauseAction: showPauseAction,
      onPlay: onPlay,
      onPlayNext: onPlayNext,
      onToggleFavorite: onToggleFavorite,
      compact: true,
    );
    final metaSection = _HeroMetaSection(
      key: const ValueKey<String>('song-detail-meta-compact'),
      meta: meta,
      compact: true,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            key: const ValueKey<String>('song-detail-top-bar'),
            height: kToolbarHeight,
            child: AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: kToolbarHeight,
              leadingWidth: 40,
              titleSpacing: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: AppBackButton(onPressed: onBack),
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: <Widget>[
                Builder(
                  builder: (buttonContext) => IconButton(
                    onPressed: () => onMore(buttonContext),
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          LayoutBuilder(
            builder: (context, constraints) {
              final coverSize = (constraints.maxWidth * 0.27)
                  .clamp(82.0, 104.0)
                  .toDouble();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      _HeroCover(
                        coverUrl: coverUrl,
                        size: coverSize,
                        compact: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: coverSize,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              titleSection,
                              const SizedBox(height: 8),
                              actionSection,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  metaSection,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroCover extends StatelessWidget {
  const _HeroCover({
    required this.coverUrl,
    this.size = 180,
    this.compact = false,
  });

  final String coverUrl;
  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(compact ? size / 2 : 24),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: compact ? 28 : 48,
        color: Theme.of(context).hintColor,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? size / 2 : 24),
      child: coverUrl.trim().isEmpty
          ? fallback
          : AppNetworkImage(
              url: coverUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: 480,
              fallback: fallback,
            ),
    );
  }
}

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({
    required this.config,
    required this.title,
    required this.artistLabel,
    required this.albumLabel,
    this.compact = false,
    this.onTapArtist,
    this.onTapAlbum,
  });

  final AppConfigState config;
  final String title;
  final String artistLabel;
  final String albumLabel;
  final bool compact;
  final VoidCallback? onTapArtist;
  final VoidCallback? onTapAlbum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: ValueKey<String>(
        compact ? 'song-detail-info-compact' : 'song-detail-info-wide',
      ),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (compact
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.headlineMedium)
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: compact ? 1.1 : 1.05,
                  ),
        ),
        if (!compact) ...<Widget>[
          const SizedBox(height: 16),
          _InfoLine(
            label: AppI18n.t(config, 'player.meta.artist'),
            value: artistLabel,
            onTap: onTapArtist,
            compact: compact,
          ),
          const SizedBox(height: 8),
          _InfoLine(
            label: AppI18n.t(config, 'player.meta.album'),
            value: albumLabel,
            onTap: onTapAlbum,
            compact: compact,
          ),
        ],
      ],
    );
  }
}

class _HeroMetaSection extends StatelessWidget {
  const _HeroMetaSection({required this.meta, this.compact = false, super.key});

  final List<_MetaItem> meta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        key: const ValueKey<String>('song-detail-meta-lines-compact'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: meta
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _MetaLine(item),
              ),
            )
            .toList(growable: false),
      );
    }
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 12,
      runSpacing: 10,
      children: meta
          .map((item) => _MetaLabel(item, compact: compact))
          .toList(growable: false),
    );
  }
}

class _HeroActions extends StatelessWidget {
  const _HeroActions({
    required this.config,
    required this.isFavorited,
    required this.showPauseAction,
    required this.onPlay,
    required this.onPlayNext,
    required this.onToggleFavorite,
    this.compact = false,
    super.key,
  });

  final AppConfigState config;
  final bool isFavorited;
  final bool showPauseAction;
  final VoidCallback onPlay;
  final VoidCallback onPlayNext;
  final VoidCallback onToggleFavorite;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final playLabel = AppI18n.t(
      config,
      showPauseAction ? 'player.action.pause' : 'song.action.play',
    );
    final favoriteLabel = AppI18n.t(
      config,
      isFavorited ? 'detail.favorite.remove_song' : 'detail.favorite.add_song',
    );
    if (compact) {
      return Row(
        key: const ValueKey<String>('song-detail-actions-row-compact'),
        children: <Widget>[
          FilledButton(
            onPressed: onPlay,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(playLabel),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onToggleFavorite,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: Text(favoriteLabel),
          ),
        ],
      );
    }
    final playNextLabel = AppI18n.t(config, 'song.action.play_next');
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        FilledButton(onPressed: onPlay, child: Text(playLabel)),
        OutlinedButton(onPressed: onPlayNext, child: Text(playNextLabel)),
        OutlinedButton(onPressed: onToggleFavorite, child: Text(favoriteLabel)),
      ],
    );
  }
}

class _MetaItem {
  const _MetaItem({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel(this.item, {this.compact = false});

  final _MetaItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (compact) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.36,
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(
            '${item.label} ${item.value}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.48,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 10 : 9,
        ),
        child: Text(
          '${item.label}：${item.value}',
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine(this.item);

  final _MetaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          color: theme.colorScheme.onSurface,
          height: 1.25,
        ),
        children: <InlineSpan>[
          TextSpan(
            text: '${item.label}：',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(text: item.value),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (item.onTap == null) {
      return content;
    }
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: content,
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      '$label：$value',
      maxLines: compact ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style:
          (compact
                  ? Theme.of(context).textTheme.bodyLarge
                  : Theme.of(context).textTheme.titleMedium)
              ?.copyWith(height: 1.3),
    );
    if (onTap == null) {
      return child;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: child,
      ),
    );
  }
}

class _PlaylistSection extends ConsumerWidget {
  const _PlaylistSection({required this.title, required this.playlists});

  final String title;
  final List<PlaylistInfo> playlists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridSpec = resolveAdaptiveMediaGridSpec(
          maxWidth: constraints.maxWidth - 32,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SectionTitle(title: title),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: playlists.length,
                gridDelegate: gridSpec.sliverDelegate,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return MediaGridCard(
                    kind: MediaGridCardKind.playlist,
                    title: playlist.name,
                    subtitle: playlist.creator,
                    coverUrl: playlist.cover,
                    playCount: playlist.playCount,
                    onTap: () => context.push(
                      Uri(
                        path: AppRoutes.playlistDetail,
                        queryParameters: <String, String>{
                          'id': playlist.id,
                          'platform': playlist.platform,
                          'title': playlist.name,
                        },
                      ).toString(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
