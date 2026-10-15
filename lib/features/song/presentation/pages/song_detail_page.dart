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
import '../../../../shared/helpers/root_route_navigation_helper.dart';
import '../../../../shared/utils/cover_resolver.dart';
import '../../../my/presentation/providers/favorite_song_status_providers.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../player/domain/entities/player_queue_source.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/song_detail_content.dart';
import '../../domain/entities/song_detail_field.dart';
import '../../domain/entities/song_detail_section.dart';
import '../../domain/entities/song_detail_request.dart';
import '../providers/song_detail_providers.dart';
import '../widgets/song_detail_section_sliver.dart';

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
  late SongDetailRequest _request;
  late DetailSongActionHandler _songActions;

  @override
  void initState() {
    super.initState();
    _initializeSong();
  }

  @override
  void didUpdateWidget(covariant SongDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.platform != widget.platform) {
      _initializeSong();
    }
  }

  void _initializeSong() {
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
    final request = _request;
    Future.microtask(() {
      if (mounted && request.cacheKey == _request.cacheKey) {
        ref
            .read(songDetailControllerProvider(request.cacheKey).notifier)
            .initialize(request);
      }
    });
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
      child: _buildBody(context: context, content: content),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required SongDetailContent content,
  }) {
    ref.watch(
      appConfigProvider.select(
        (config) => (config.localeCode, config.apiBaseUrl, config.authToken),
      ),
    );
    final config = ref.read(appConfigProvider);
    final song = content.song;
    final platforms =
        ref.watch(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    final coverUrl = _songActions.resolveCoverUrl(song);

    const useWideLayout = false;
    return LayoutBuilder(
      builder: (context, constraints) => SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Consumer(
                  builder: (context, ref, _) {
                    final playback = ref.watch(
                      playerControllerProvider.select((player) {
                        final isCurrent = isCurrentSongTrack(
                          player.displayTrack,
                          song,
                        );
                        return (
                          isCurrent: isCurrent,
                          showPause: isCurrent && player.isPlaying,
                        );
                      }),
                    );
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
                    final onPrimaryPlay = playback.isCurrent
                        ? () => ref
                              .read(playerControllerProvider.notifier)
                              .togglePlayPause()
                        : () => _songActions.playSongNow(song);
                    final morePlayActionLabel = AppI18n.t(
                      config,
                      playback.showPause
                          ? 'player.action.pause'
                          : 'song.action.play',
                    );
                    return _SongHeroCard(
                      key: const ValueKey<String>('song-detail-header-compact'),
                      config: config,
                      useWideLayout: useWideLayout,
                      title: song.title.trim().isEmpty
                          ? widget.title
                          : song.title,
                      coverUrl: coverUrl,
                      platformLabel: resolvePlatformLabel(
                        song.platform.isEmpty ? widget.platform : song.platform,
                        platforms: platforms,
                      ),
                      fields: content.fields,
                      duration: formatDurationSecondsLabel('${song.duration}'),
                      artistLabel: song.artist,
                      albumLabel: (song.album?.name.trim().isEmpty ?? true)
                          ? '-'
                          : song.album!.name.trim(),
                      isFavorited: isFavorited,
                      showPauseAction: playback.showPause,
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
                                platformId: _songActions.resolvePlatformId(
                                  song,
                                ),
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
                                  'platform': _songActions.resolvePlatformId(
                                    song,
                                  ),
                                  'title': song.album!.name,
                                },
                              ).toString(),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ),
            ..._buildSectionSlivers(
              sections: content.sections,
              gridWidth: constraints.maxWidth - 32,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSectionSlivers({
    required List<SongDetailSection> sections,
    required double gridWidth,
  }) {
    final gridSpec = resolveAdaptiveMediaGridSpec(maxWidth: gridWidth);
    return <Widget>[
      for (var index = 0; index < sections.length; index++)
        if (!sections[index].isEmpty)
          buildSongDetailSectionSliver(
            key: ValueKey<String>('song-sections-${_request.cacheKey}-$index'),
            section: sections[index],
            gridSpec: gridSpec,
            onTapSong: (songs, index) =>
                _songActions.playAll(context, songs, startIndex: index),
            onTapAlbum: (album) => context.pushAlbumDetail(
              id: album.id,
              platform: album.platform,
              title: album.name,
            ),
            onTapPlaylist: (playlist) => context.pushPlaylistDetail(
              id: playlist.id,
              platform: playlist.platform,
              title: playlist.name,
            ),
            onTapMv: (mv) => _openResource(
              AppRoutes.videoDetail,
              mv.id,
              mv.platform,
              mv.name,
            ),
            onMoreSong: (song) => _songActions.showSongActions(
              context: context,
              song: song,
              coverUrl: _songActions.resolveCoverUrl(song),
            ),
            onLikeSong: _songActions.toggleSongFavorite,
            buildSongStatus: _buildSongStatus,
            resolveSongCover: _songActions.resolveCoverUrl,
            resolveCover: _resolveResourceCover,
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

  Widget _buildSongStatus(
    BuildContext context,
    SongInfo song,
    Widget Function(bool isLiked, bool isCurrent) builder,
  ) => Consumer(
    builder: (context, ref, _) {
      final isCurrent = ref.watch(
        playerControllerProvider.select(
          (player) => isCurrentSongTrack(player.displayTrack, song),
        ),
      );
      final isLiked = ref.watch(
        favoriteSongStatusProvider.select(
          (favorite) => favorite.songKeys.contains(
            buildFavoriteSongKey(
              songId: song.id,
              platform: _songActions.resolvePlatformId(song),
            ),
          ),
        ),
      );
      return builder(isLiked, isCurrent);
    },
  );

  String _resolveResourceCover(String cover, String platform) =>
      resolveTemplateCoverUrl(
        platforms:
            ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[],
        platformId: platform,
        cover: cover,
        size: 300,
      );

  void _openResource(String path, String id, String platform, String title) {
    context.push(
      Uri(
        path: path,
        queryParameters: <String, String>{
          'id': id,
          'platform': platform,
          'title': title,
        },
      ).toString(),
    );
  }
}

class _SongHeroCard extends StatelessWidget {
  const _SongHeroCard({
    required this.config,
    required this.useWideLayout,
    required this.title,
    required this.coverUrl,
    required this.platformLabel,
    required this.fields,
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
  final List<SongDetailField> fields;
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
                  if (fields.isNotEmpty)
                    _HeroMetaSection(
                      key: const ValueKey<String>('song-detail-fields'),
                      meta: [
                        for (final field in fields)
                          _MetaItem(label: field.label, value: field.value),
                      ],
                      compact: true,
                    ),
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
