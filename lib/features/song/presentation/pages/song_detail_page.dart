import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/glass/app_glass_material.dart';
import '../../../../app/theme/glass/app_glass_scope.dart';
import '../../../../app/theme/skin/app_skin_icon.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../../shared/layout/adaptive_media_grid_spec.dart';
import '../../../../shared/helpers/album_id_helper.dart';
import '../../../../shared/helpers/current_track_helper.dart';
import '../../../../shared/helpers/detail_song_action_handler.dart';
import '../../../../shared/helpers/platform_label_helper.dart';
import '../../../../shared/helpers/song_artist_navigation_helper.dart';
import '../../../../shared/helpers/song_detail_navigation_helper.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/compact_number_formatter.dart';
import '../../../../shared/utils/favorite_song_key.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/music_detail_slivers.dart';
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
import '../../domain/entities/song_detail_section.dart';
import '../../domain/entities/song_detail_request.dart';
import '../providers/song_detail_providers.dart';
import '../widgets/song_detail_section_sliver.dart';
import '../widgets/song_detail_info_cards.dart';

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
    final platforms = ref.watch(
      onlinePlatformsProvider.select(
        (state) => state.value ?? const <OnlinePlatform>[],
      ),
    );
    final coverUrl = _songActions.resolveCoverUrl(song);

    return LayoutBuilder(
      builder: (context, constraints) => SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverMainAxisGroup(
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: _SongDetailAppBar(
                      title: song.title.trim().isEmpty
                          ? widget.title
                          : song.title,
                      config: config,
                      onBack: () => context.appPopOrGo(),
                      onMore: (anchorContext) =>
                          _showMoreSongActions(anchorContext, song, coverUrl),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _SongHeroCard(
                        key: const ValueKey<String>(
                          'song-detail-header-compact',
                        ),
                        title: song.title.trim().isEmpty
                            ? widget.title
                            : song.title,
                        coverUrl: coverUrl,
                        artistLabel: song.artist,
                        albumLabel: song.album?.name.trim() ?? '',
                        actions: _buildPrimaryActions(song, config),
                        onTapArtist: song.artists.isEmpty
                            ? null
                            : () => unawaited(
                                openSongArtistSelection(
                                  context: context,
                                  platformId: _songActions.resolvePlatformId(
                                    song,
                                  ),
                                  artists: song.artists,
                                  onError: AppMessageService.showError,
                                ),
                              ),
                        onTapAlbum: hasValidAlbumId(song.album?.id ?? '')
                            ? () => context.pushAlbumDetail(
                                id: song.album!.id,
                                platform: _songActions.resolvePlatformId(song),
                                title: song.album!.name,
                              )
                            : null,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                      child: SongDetailInfoCards(
                        source: resolvePlatformLabel(
                          song.platform.trim().isEmpty
                              ? widget.platform
                              : song.platform,
                          platforms: platforms,
                        ),
                        duration: formatDurationSecondsLabel(
                          '${song.duration}',
                        ),
                        fields: content.fields,
                        sourceLabel: AppI18n.t(
                          config,
                          'song.detail.meta.source',
                        ),
                        durationLabel: AppI18n.t(
                          config,
                          'song.detail.meta.duration',
                        ),
                      ),
                    ),
                  ),
                  ..._buildSectionSlivers(
                    sections: content.sections,
                    song: song,
                    gridWidth: constraints.maxWidth - 32,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryActions(SongInfo song, AppConfigState config) => Consumer(
    builder: (context, ref, _) {
      final playback = ref.watch(
        playerControllerProvider.select((player) {
          final isCurrent = isCurrentSongTrack(player.displayTrack, song);
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
      return _HeroActions(
        key: const ValueKey<String>('song-detail-actions-compact'),
        config: config,
        isFavorited: isFavorited,
        showPauseAction: playback.showPause,
        onPlay: playback.isCurrent
            ? () =>
                  ref.read(playerControllerProvider.notifier).togglePlayPause()
            : () => _songActions.playSongNow(song),
        onToggleFavorite: () => _toggleSongFavorite(isFavorited, song: song),
      );
    },
  );

  void _showMoreSongActions(
    BuildContext anchorContext,
    SongInfo song,
    String coverUrl,
  ) {
    final player = ref.read(playerControllerProvider);
    final isCurrent = isCurrentSongTrack(player.displayTrack, song);
    _songActions.showSongActions(
      context: anchorContext,
      song: song,
      coverUrl: coverUrl,
      playActionLabel: AppI18n.t(
        ref.read(appConfigProvider),
        isCurrent && player.isPlaying
            ? 'player.action.pause'
            : 'song.action.play',
      ),
      onPlay: isCurrent
          ? () => ref.read(playerControllerProvider.notifier).togglePlayPause()
          : () => _songActions.playSongNow(song),
      anchorContext: anchorContext,
      includeViewDetail: false,
      forceBottomSheet: true,
    );
  }

  List<Widget> _buildSectionSlivers({
    required List<SongDetailSection> sections,
    required SongInfo song,
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
            songId: _request.id,
            platform: _request.platform,
            moreLabel: AppI18n.t(ref.read(appConfigProvider), 'common.more'),
            onMoreSheetMusic: () => openSongSheetMusicPage(
              context: context,
              songId: _request.id,
              platformId: _request.platform,
              title: song.title.trim().isEmpty ? widget.title : song.title,
            ),
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

class _SongDetailAppBar extends StatelessWidget {
  const _SongDetailAppBar({
    required this.title,
    required this.config,
    required this.onBack,
    required this.onMore,
  });

  final String title;
  final AppConfigState config;
  final VoidCallback onBack;
  final ValueChanged<BuildContext> onMore;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
    );
    final moreButton = Builder(
      builder: (buttonContext) => MusicDetailActionButton(
        icon: const Icon(Icons.more_horiz_rounded),
        tooltip: AppI18n.t(config, 'common.more'),
        onPressed: () => onMore(buttonContext),
      ),
    );

    return SizedBox(
      key: const ValueKey<String>('song-detail-top-bar'),
      height: kToolbarHeight,
      child: AppGlassScope.controlsEnabled(context)
          ? GlassAppBar(
              toolbarHeight: kToolbarHeight,
              centerTitle: false,
              buttonSettings: AppGlassMaterial.settings(
                context,
                navigation: true,
              ),
              leading: MusicDetailActionButton(
                icon: const AppSkinIcon(role: AppSkinIconRole.back),
                tooltip: AppI18n.t(config, 'common.back'),
                onPressed: onBack,
              ),
              title: titleWidget,
              actions: <Widget>[moreButton],
            )
          : AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: AppBackButton(onPressed: onBack),
              title: titleWidget,
              actions: <Widget>[moreButton],
            ),
    );
  }
}

class _SongHeroCard extends StatelessWidget {
  const _SongHeroCard({
    required this.title,
    required this.coverUrl,
    required this.artistLabel,
    required this.albumLabel,
    required this.actions,
    this.onTapArtist,
    this.onTapAlbum,
    super.key,
  });

  final String title;
  final String coverUrl;
  final String artistLabel;
  final String albumLabel;
  final Widget actions;
  final VoidCallback? onTapArtist;
  final VoidCallback? onTapAlbum;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final coverSize = (constraints.maxWidth * 0.27)
                .clamp(72.0, 104.0)
                .toDouble();
            return Row(
              key: const ValueKey<String>('song-detail-hero-row'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _HeroCover(coverUrl: coverUrl, size: coverSize),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    key: const ValueKey<String>('song-detail-info-compact'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _HeroInfoLine(
                        key: const ValueKey<String>('song-detail-artist'),
                        value: artistLabel.isEmpty ? '-' : artistLabel,
                        onTap: onTapArtist,
                      ),
                      const SizedBox(height: 2),
                      _HeroInfoLine(
                        key: const ValueKey<String>('song-detail-album'),
                        value: albumLabel.isEmpty ? '-' : albumLabel,
                        onTap: onTapAlbum,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        actions,
      ],
    ),
  );
}

class _HeroCover extends StatelessWidget {
  const _HeroCover({required this.coverUrl, required this.size});

  final String coverUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: 28,
        color: Theme.of(context).hintColor,
      ),
    );
    return ClipOval(
      key: const ValueKey<String>('song-detail-cover'),
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

class _HeroInfoLine extends StatelessWidget {
  const _HeroInfoLine({required this.value, this.onTap, super.key});

  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.3,
      ),
    );
    return onTap == null
        ? text
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: text,
            ),
          );
  }
}

class _HeroActions extends StatelessWidget {
  const _HeroActions({
    required this.config,
    required this.isFavorited,
    required this.showPauseAction,
    required this.onPlay,
    required this.onToggleFavorite,
    super.key,
  });

  final AppConfigState config;
  final bool isFavorited;
  final bool showPauseAction;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final useGlass = AppGlassScope.controlsEnabled(context);
    final playLabel = AppI18n.t(
      config,
      showPauseAction ? 'player.action.pause' : 'song.action.play',
    );
    final favoriteLabel = AppI18n.t(
      config,
      isFavorited ? 'detail.favorite.remove_song' : 'detail.favorite.add_song',
    );
    final playIcon = showPauseAction
        ? Icons.pause_rounded
        : Icons.play_arrow_rounded;
    final favoriteIcon = Icon(
      isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: isFavorited ? colors.primary : colors.onSurfaceVariant,
      size: 24,
    );
    final playContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(playIcon, size: 24),
        const SizedBox(width: 8),
        Text(playLabel),
      ],
    );

    return Wrap(
      key: const ValueKey<String>('song-detail-actions-row-compact'),
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (useGlass)
          GlassButton.custom(
            onTap: onPlay,
            label: playLabel,
            shape: const LiquidRoundedRectangle(borderRadius: 16),
            useOwnLayer: true,
            quality: AppGlassScope.qualityOf(context),
            style: GlassButtonStyle.prominent,
            settings: LiquidGlassSettings(glassColor: colors.primary),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: DefaultTextStyle(
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  child: IconTheme(
                    data: IconThemeData(color: colors.onPrimary),
                    child: playContent,
                  ),
                ),
              ),
            ),
          )
        else
          FilledButton(
            onPressed: onPlay,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: playContent,
          ),
        Semantics(
          toggled: isFavorited,
          child: useGlass
              ? Tooltip(
                  message: favoriteLabel,
                  excludeFromSemantics: true,
                  child: GlassIconButton(
                    icon: favoriteIcon,
                    onPressed: onToggleFavorite,
                    semanticLabel: favoriteLabel,
                    size: 48,
                    useOwnLayer: true,
                    quality: AppGlassScope.qualityOf(context),
                  ),
                )
              : IconButton.filledTonal(
                  onPressed: onToggleFavorite,
                  tooltip: favoriteLabel,
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(48),
                    backgroundColor: isFavorited
                        ? colors.primaryContainer
                        : colors.surfaceContainerHighest,
                    shape: const CircleBorder(),
                  ),
                  icon: favoriteIcon,
                ),
        ),
      ],
    );
  }
}
