import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/skin/app_skin_background.dart';
import '../../../../app/theme/skin/app_skin_icon.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../shared/layout/adaptive_media_grid_spec.dart';
import '../../../../shared/helpers/song_artist_navigation_helper.dart';
import '../../../../shared/helpers/album_id_helper.dart';
import '../../../../shared/helpers/platform_label_helper.dart';
import '../../../../shared/helpers/root_route_navigation_helper.dart';
import '../../../../shared/helpers/song_detail_navigation_helper.dart';
import '../../../../shared/helpers/user_playlist_song_action_helper.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/helpers/current_track_helper.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/favorite_song_key.dart';
import '../../../../shared/widgets/song_actions_sheet.dart';
import '../../../../shared/widgets/underline_tab.dart';
import '../../../../shared/utils/cover_resolver.dart';
import '../../../../shared/utils/share_link_builder.dart';
import '../../domain/entities/home_page_section.dart';
import '../../domain/entities/home_page_state.dart';
import '../providers/home_page_providers.dart';
import '../../../my/presentation/providers/favorite_song_status_providers.dart';
import '../../../download/domain/entities/download_task.dart';
import '../../../download/presentation/providers/download_providers.dart';
import '../../../download/presentation/widgets/download_quality_sheet.dart';
import '../../../player/domain/entities/player_playback_state.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/domain/entities/player_quality_option.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../radio/presentation/helpers/radio_playback_helper.dart';
import 'home_sections.dart';
import 'home_search_field.dart';

const _entries = <_DiscoverEntry>[
  _DiscoverEntry(
    type: _DiscoverEntryType.ranking,
    iconRole: AppSkinIconRole.homeRanking,
    titleKey: 'home.entry.ranking',
  ),
  _DiscoverEntry(
    type: _DiscoverEntryType.playlist,
    iconRole: AppSkinIconRole.homePlaylist,
    titleKey: 'home.entry.playlist',
  ),
  _DiscoverEntry(
    type: _DiscoverEntryType.artist,
    iconRole: AppSkinIconRole.homeArtist,
    titleKey: 'home.entry.artist',
  ),
  _DiscoverEntry(
    type: _DiscoverEntryType.video,
    iconRole: AppSkinIconRole.homeVideo,
    titleKey: 'home.entry.video',
  ),
  _DiscoverEntry(
    type: _DiscoverEntryType.radio,
    iconRole: AppSkinIconRole.homeRadio,
    titleKey: 'home.entry.radio',
  ),
];

enum _DiscoverEntryType { ranking, playlist, artist, video, radio }

class DiscoverHomeTab extends ConsumerStatefulWidget {
  const DiscoverHomeTab({super.key});

  @override
  ConsumerState<DiscoverHomeTab> createState() => _DiscoverHomeTabState();
}

class _DiscoverHomeTabState extends ConsumerState<DiscoverHomeTab> {
  late final PageController _pageController;
  late final Map<HomePageKind, ScrollController> _scrollControllers;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollControllers = <HomePageKind, ScrollController>{
      HomePageKind.recommend: ScrollController()
        ..addListener(_handleRecommendScroll),
      HomePageKind.discover: ScrollController(),
    };
    Future.microtask(() {
      if (mounted) {
        unawaited(ref.read(homePageControllerProvider.notifier).initialize());
      }
    });
  }

  @override
  void dispose() {
    _scrollControllers[HomePageKind.recommend]
      ?..removeListener(_handleRecommendScroll)
      ..dispose();
    _scrollControllers[HomePageKind.discover]?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final homeState = ref.watch(homePageControllerProvider);
    final searchDefaultState = ref.watch(searchDefaultPlaceholderProvider);
    final globalPlatforms =
        ref.watch(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    final playerState = ref.watch(playerControllerProvider);
    final homeController = ref.read(homePageControllerProvider.notifier);
    final favoriteSongKeys = ref.watch(
      favoriteSongStatusProvider.select((state) => state.songKeys),
    );
    final searchPlaceholderPrimary =
        searchDefaultState.currentEntry?.key.trim().isNotEmpty == true
        ? searchDefaultState.currentEntry!.key.trim()
        : AppI18n.t(config, 'home.search');
    final searchPlaceholderSecondary =
        searchDefaultState.currentEntry?.description.trim().isNotEmpty == true
        ? searchDefaultState.currentEntry!.description.trim()
        : null;
    final availablePages = homeState.availablePages;
    return Stack(
      children: <Widget>[
        const Positioned.fill(child: _HomeBackground()),
        Column(
          children: <Widget>[
            SafeArea(
              bottom: false,
              child: availablePages.length > 1
                  ? _HomePageTabs(
                      pages: availablePages,
                      selectedPage: homeState.selectedPage,
                      config: config,
                      onSelected: (page) => _selectPage(
                        page: page,
                        availablePages: availablePages,
                      ),
                    )
                  : const SizedBox(height: 8),
            ),
            Expanded(
              child: availablePages.isEmpty
                  ? homeState.platformErrorMessage == null
                        ? const Center(
                            child: SizedBox.square(
                              key: ValueKey<String>('home-platform-loading'),
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : _HomePlatformError(
                            message: homeState.platformErrorMessage!,
                            retryText: AppI18n.t(config, 'home.retry'),
                            onRetry: homeController.retryPlatforms,
                          )
                  : PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        if (index >= 0 && index < availablePages.length) {
                          unawaited(
                            homeController.selectPage(availablePages[index]),
                          );
                        }
                      },
                      children: availablePages
                          .map(
                            (page) => _buildContentPage(
                              context: context,
                              page: page,
                              homeState: homeState,
                              config: config,
                              searchPlaceholderPrimary:
                                  searchPlaceholderPrimary,
                              searchPlaceholderSecondary:
                                  searchPlaceholderSecondary,
                              globalPlatforms: globalPlatforms,
                              favoriteSongKeys: favoriteSongKeys,
                              playerState: playerState,
                            ),
                          )
                          .toList(growable: false),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContentPage({
    required BuildContext context,
    required HomePageKind page,
    required HomePageState homeState,
    required AppConfigState config,
    required String searchPlaceholderPrimary,
    required String? searchPlaceholderSecondary,
    required List<OnlinePlatform> globalPlatforms,
    required Set<String> favoriteSongKeys,
    required PlayerPlaybackState playerState,
  }) {
    final content = homeState.contentFor(page);
    final selectedPlatformId = content.selectedPlatformId ?? '';
    final homeController = ref.read(homePageControllerProvider.notifier);
    return LayoutBuilder(
      key: PageStorageKey<String>('home-${page.name}'),
      builder: (context, constraints) {
        final gridWidth =
            constraints.maxWidth - LayoutTokens.compactPageGutter * 2;
        final gridSpec = resolveAdaptiveMediaGridSpec(maxWidth: gridWidth);
        final quickEntryGridSpec = resolveHomeQuickEntryGridSpec(
          maxWidth: gridWidth,
        );
        return RefreshIndicator(
          onRefresh: () async {
            final error = await homeController.refresh();
            if (error != null && mounted) {
              AppMessageService.showError(error);
            }
          },
          child: CustomScrollView(
            controller: _scrollControllers[page],
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  LayoutTokens.compactPageGutter,
                  8,
                  LayoutTokens.compactPageGutter,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _HomeTopControls(
                    config: config,
                    showEntries: page == HomePageKind.discover,
                    searchPlaceholderPrimary: searchPlaceholderPrimary,
                    searchPlaceholderSecondary: searchPlaceholderSecondary,
                    onSearchTap: () => _openSearchPage(
                      context: context,
                      config: config,
                      platformId: selectedPlatformId,
                    ),
                    onEntryTap: (entry) => _openEntry(
                      context: context,
                      config: config,
                      platformId: selectedPlatformId,
                      entry: entry,
                    ),
                    onParseUrl: () => context.push(AppRoutes.parseSourceUrl),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LayoutTokens.compactPageGutter + 4,
                ),
                sliver: SliverToBoxAdapter(
                  child: _PlatformBar(
                    selectedPlatformId: content.selectedPlatformId,
                    onSelected: homeController.selectPlatform,
                    chips: homeState
                        .platformsFor(page)
                        .map(
                          (platform) => _PlatformChipData(
                            id: platform.id,
                            label: platform.shortName,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              ...buildHomeSectionSlivers(
                state: content,
                gridSpec: gridSpec,
                quickEntryGridSpec: quickEntryGridSpec,
                loadingText: AppI18n.t(config, 'home.loading'),
                emptyText: AppI18n.t(
                  config,
                  page == HomePageKind.recommend
                      ? 'home.recommend.empty'
                      : 'home.empty',
                ),
                retryText: AppI18n.t(config, 'home.retry'),
                onRetry: homeController.retry,
                sectionActionOf: (section) => _buildSectionAction(
                  context: context,
                  config: config,
                  sectionType: section.sectionType,
                  selectedPlatformId: selectedPlatformId,
                ),
                onTapSong: (songs, index) => _playDiscoverSong(
                  context: context,
                  ref: ref,
                  songs: songs,
                  startIndex: index,
                ),
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
                onTapMv: (mv) => _openDiscoverDetailPage(
                  context: context,
                  path: AppRoutes.videoDetail,
                  id: mv.id,
                  platform: mv.platform,
                  title: mv.name,
                ),
                onTapArtist: (artist) => _openDiscoverDetailPage(
                  context: context,
                  path: AppRoutes.artistDetail,
                  id: artist.id,
                  platform: artist.platform,
                  title: artist.name,
                ),
                onTapRanking: (ranking) => _openDiscoverDetailPage(
                  context: context,
                  path: AppRoutes.rankingDetail,
                  id: ranking.id,
                  platform: ranking.platform,
                  title: ranking.name,
                ),
                onTapRadio: (radio) => handleRadioPlayback(ref, radio),
                onTapEntry: (entry) => _openPageEntry(
                  context: context,
                  config: config,
                  platformId: selectedPlatformId,
                  entry: entry,
                ),
                onMoreSong: (song) => _showDiscoverSongActions(
                  context: context,
                  ref: ref,
                  song: song,
                ),
                isSongLiked: (song) => favoriteSongKeys.contains(
                  buildFavoriteSongKey(
                    songId: song.id,
                    platform: song.platform.isEmpty
                        ? selectedPlatformId
                        : song.platform,
                  ),
                ),
                onLikeSong: (song) => _toggleSongFavorite(
                  ref: ref,
                  song: song,
                  fallbackPlatformId: selectedPlatformId,
                ),
                isCurrentSong: (song) =>
                    isCurrentSongTrack(playerState.currentTrack, song),
                isRadioPlaying: (radio) =>
                    playerState.isRadioMode &&
                    playerState.currentRadioId == radio.id &&
                    playerState.currentRadioPlatform == radio.platform,
                isEntryRadioPlaying: (entry) =>
                    playerState.isRadioMode &&
                    playerState.currentRadioId == entry.targetId &&
                    playerState.currentRadioPlatform == selectedPlatformId,
                resolveSongCover: (song) => _resolveDiscoverSongCover(
                  config: config,
                  platforms: globalPlatforms,
                  platformId: content.selectedPlatformId,
                  song: song,
                ),
                resolveAlbumCover: (album) => _resolveDiscoverGridCover(
                  platforms: globalPlatforms,
                  selectedPlatformId: content.selectedPlatformId,
                  itemPlatformId: album.platform,
                  cover: album.cover,
                ),
                resolvePlaylistCover: (playlist) => _resolveDiscoverGridCover(
                  platforms: globalPlatforms,
                  selectedPlatformId: content.selectedPlatformId,
                  itemPlatformId: playlist.platform,
                  cover: playlist.cover,
                ),
                resolveMvCover: (mv) => _resolveDiscoverGridCover(
                  platforms: globalPlatforms,
                  selectedPlatformId: content.selectedPlatformId,
                  itemPlatformId: mv.platform,
                  cover: mv.cover,
                ),
                resolveArtistCover: (artist) => _resolveDiscoverGridCover(
                  platforms: globalPlatforms,
                  selectedPlatformId: content.selectedPlatformId,
                  itemPlatformId: artist.platform,
                  cover: artist.cover,
                ),
                resolveRadioCover: (radio) => _resolveDiscoverGridCover(
                  platforms: globalPlatforms,
                  selectedPlatformId: content.selectedPlatformId,
                  itemPlatformId: radio.platform,
                  cover: radio.cover,
                ),
              ),
              if (page == HomePageKind.recommend && content.loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (page == HomePageKind.recommend &&
                  content.loadMoreErrorMessage != null)
                SliverToBoxAdapter(
                  child: Center(
                    child: TextButton(
                      onPressed: homeController.loadMore,
                      child: Text(
                        AppI18n.t(config, 'common.load_more_failed_retry'),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        );
      },
    );
  }

  void _handleRecommendScroll() {
    final controller = _scrollControllers[HomePageKind.recommend];
    if (controller == null ||
        !controller.hasClients ||
        controller.position.extentAfter > 240) {
      return;
    }
    unawaited(ref.read(homePageControllerProvider.notifier).loadMore());
  }

  void _selectPage({
    required HomePageKind page,
    required List<HomePageKind> availablePages,
  }) {
    final index = availablePages.indexOf(page);
    if (index < 0) {
      return;
    }
    unawaited(ref.read(homePageControllerProvider.notifier).selectPage(page));
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _playDiscoverSong({
    required BuildContext context,
    required WidgetRef ref,
    required List<SongInfo> songs,
    required int startIndex,
  }) async {
    if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) {
      return;
    }
    final selectedPlatformId = ref
        .read(homePageControllerProvider)
        .contentFor(ref.read(homePageControllerProvider).selectedPage)
        .selectedPlatformId;
    final playerController = ref.read(playerControllerProvider.notifier);
    final config = ref.read(appConfigProvider);
    final platforms =
        ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    try {
      final tracks = songs
          .map((song) {
            final artworkUrl = _resolveDiscoverSongCover(
              config: config,
              platforms: platforms,
              platformId: selectedPlatformId,
              song: song,
              size: maxCoverSize,
            );
            return PlayerTrack(
              id: song.id,
              title: song.title,
              links: song.links,
              artist: song.artist,
              album: song.album?.name.trim().isEmpty ?? true
                  ? null
                  : song.album?.name,
              albumId: song.album?.id.trim().isEmpty ?? true
                  ? null
                  : song.album?.id,
              artists: song.artists,
              mvId: song.mvId,
              artworkUrl: artworkUrl.isEmpty ? null : artworkUrl,
              platform: selectedPlatformId,
            );
          })
          .toList(growable: false);
      await playerController.replaceQueue(tracks, startIndex: startIndex);
    } catch (error) {
      AppMessageService.showError(
        AppI18n.format(
          ref.read(appConfigProvider),
          'detail.play_failed',
          <String, String>{'error': '$error'},
        ),
      );
    }
  }

  HomeSectionAction? _buildSectionAction({
    required BuildContext context,
    required AppConfigState config,
    required HomeSectionType sectionType,
    required String selectedPlatformId,
  }) {
    if (sectionType == HomeSectionType.newSongs) {
      return HomeSectionAction(
        label: AppI18n.t(config, 'common.more'),
        onTap: () => context.push(
          Uri(
            path: AppRoutes.newSong,
            queryParameters: <String, String>{
              if (selectedPlatformId.isNotEmpty) 'platform': selectedPlatformId,
            },
          ).toString(),
        ),
      );
    }
    if (sectionType == HomeSectionType.newAlbums) {
      return HomeSectionAction(
        label: AppI18n.t(config, 'common.more'),
        onTap: () => context.push(
          Uri(
            path: AppRoutes.newAlbum,
            queryParameters: <String, String>{
              if (selectedPlatformId.isNotEmpty) 'platform': selectedPlatformId,
            },
          ).toString(),
        ),
      );
    }
    if (sectionType == HomeSectionType.ranking) {
      return HomeSectionAction(
        label: AppI18n.t(config, 'common.more'),
        onTap: () => context.push(
          Uri(
            path: AppRoutes.rankingList,
            queryParameters: <String, String>{
              if (selectedPlatformId.isNotEmpty) 'platform': selectedPlatformId,
            },
          ).toString(),
        ),
      );
    }
    return null;
  }

  void _showDiscoverSongActions({
    required BuildContext context,
    required WidgetRef ref,
    required SongInfo song,
  }) {
    final config = ref.read(appConfigProvider);
    final platformId = ref
        .read(homePageControllerProvider)
        .contentFor(ref.read(homePageControllerProvider).selectedPage)
        .selectedPlatformId;
    if (platformId == null || platformId.trim().isEmpty) {
      AppMessageService.showWarning(
        AppI18n.t(config, 'home.platform_not_ready'),
      );
      return;
    }

    final title = song.title;
    final subtitle = song.artist;
    final albumId = song.album?.id.trim() ?? '';
    final albumTitle = song.album?.name.trim() ?? '';
    final platforms =
        ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    final canViewAlbum =
        hasValidAlbumId(albumId) &&
        platformSupportsAlbumDetail(
          platformId: platformId,
          platforms: platforms,
        );
    final artistActionLabel =
        platformSupportsArtistDetail(
          platformId: platformId,
          platforms: platforms,
        )
        ? songArtistActionLabel(song.artists, localeCode: config.localeCode)
        : null;
    final sourceLabel = AppI18n.format(
      ref.read(appConfigProvider),
      'song.source',
      <String, String>{
        'platform': resolvePlatformLabel(platformId, platforms: platforms),
      },
    );
    final artworkUrl = _resolveDiscoverSongCover(
      config: config,
      platforms: platforms,
      platformId: platformId,
      song: song,
    );
    final playerArtworkUrl = _resolveDiscoverSongCover(
      config: config,
      platforms: platforms,
      platformId: platformId,
      song: song,
      size: maxCoverSize,
    );
    final qualities = buildDownloadQualityOptions(
      links: song.links,
      qualityDescriptions: _platformQualityDescriptions(
        platforms: platforms,
        platformId: platformId,
      ),
    );

    showSongActionsSheet(
      context: context,
      coverUrl: artworkUrl.isEmpty ? null : artworkUrl,
      title: title,
      subtitle: subtitle,
      hasMv: song.hasMv,
      sourceLabel: sourceLabel,
      onPlay: () => unawaited(
        _replaceQueueFromOnlineSong(
          ref: ref,
          songId: song.id,
          title: title,
          links: song.links,
          artist: subtitle,
          album: albumTitle.isEmpty ? null : albumTitle,
          albumId: albumId.isEmpty ? null : albumId,
          artists: song.artists,
          mvId: song.mvId,
          artworkUrl: playerArtworkUrl,
          platformId: platformId,
        ),
      ),
      onPlayNext: () => unawaited(
        _insertNextFromOnlineSong(
          ref: ref,
          songId: song.id,
          title: title,
          links: song.links,
          artist: subtitle,
          album: albumTitle.isEmpty ? null : albumTitle,
          albumId: albumId.isEmpty ? null : albumId,
          artists: song.artists,
          mvId: song.mvId,
          artworkUrl: playerArtworkUrl,
          platformId: platformId,
        ),
      ),
      onAddToPlaylist: () => unawaited(
        _appendFromOnlineSong(
          ref: ref,
          songId: song.id,
          title: title,
          links: song.links,
          artist: subtitle,
          album: albumTitle.isEmpty ? null : albumTitle,
          albumId: albumId.isEmpty ? null : albumId,
          artists: song.artists,
          mvId: song.mvId,
          artworkUrl: playerArtworkUrl,
          platformId: platformId,
        ),
      ),
      onAddToUserPlaylist: () => unawaited(
        addSingleSongToUserPlaylist(
          context: context,
          ref: ref,
          song: IdPlatformInfo(id: song.id, platform: platformId),
        ),
      ),
      onDownload: qualities.isEmpty
          ? null
          : () => unawaited(
              _downloadDiscoverSong(
                context: context,
                ref: ref,
                song: song,
                platformId: platformId,
                artworkUrl: artworkUrl.isEmpty ? null : artworkUrl,
                qualities: qualities,
              ),
            ),
      onWatchMv: () => _openDiscoverSongMvDetail(
        context: context,
        platformId: platformId,
        song: song,
      ),
      onViewComment:
          platformSupportsSongComment(
            platformId: platformId,
            platforms: platforms,
          )
          ? () => _openSongComments(
              context: context,
              ref: ref,
              songId: song.id,
              platformId: platformId,
              title: title,
            )
          : null,
      onViewDetail:
          canOpenSongDetail(
            songId: song.id,
            platformId: platformId,
            platforms: platforms,
          )
          ? () => openSongDetailPage(
              context: context,
              songId: song.id,
              platformId: platformId,
              title: title,
            )
          : null,
      albumActionLabel: canViewAlbum
          ? AppI18n.t(config, 'player.action.view_album')
          : null,
      onViewAlbum: canViewAlbum
          ? () => _openAlbumDetail(
              context: context,
              albumId: albumId,
              platformId: platformId,
              albumTitle: albumTitle,
            )
          : null,
      artistActionLabel: artistActionLabel,
      onViewArtists: artistActionLabel == null
          ? null
          : () => unawaited(
              openSongArtistSelection(
                context: context,
                platformId: platformId,
                artists: song.artists,
              ),
            ),
      onCopySongName: () => unawaited(
        _copyText(
          context: context,
          value: title,
          successLabel: AppI18n.t(config, 'player.copy.name_done'),
        ),
      ),
      onCopySongShareLink: () => unawaited(
        _copyText(
          context: context,
          value: buildShareLink(
            type: 'song',
            platform: platformId,
            id: song.id,
          ),
          successLabel: AppI18n.t(config, 'player.copy.share_done'),
        ),
      ),
      onSearchSameName: () => _openSongSearch(
        context: context,
        platformId: platformId,
        keyword: title,
      ),
      onCopySongId: () => unawaited(
        _copyText(
          context: context,
          value: song.id,
          successLabel: AppI18n.t(config, 'player.copy.id_done'),
        ),
      ),
    );
  }

  Future<void> _toggleSongFavorite({
    required WidgetRef ref,
    required SongInfo song,
    required String fallbackPlatformId,
  }) async {
    final platform = song.platform.isEmpty ? fallbackPlatformId : song.platform;
    final liked = ref.read(
      favoriteSongStatusProvider.select(
        (state) => state.songKeys.contains(
          buildFavoriteSongKey(songId: song.id, platform: platform),
        ),
      ),
    );
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .toggleSongFavorite(
            songId: song.id,
            platform: platform,
            like: !liked,
          );
    } catch (error) {
      AppMessageService.showError('$error');
    }
  }

  String _resolveDiscoverSongCover({
    required AppConfigState config,
    required List<OnlinePlatform> platforms,
    required String? platformId,
    required SongInfo song,
    int size = 300,
  }) {
    final resolvedPlatform = (platformId ?? '').trim();
    if (resolvedPlatform.isEmpty) {
      return song.cover;
    }
    return resolveSongCoverUrl(
      baseUrl: config.apiBaseUrl,
      token: config.authToken ?? '',
      platforms: platforms,
      platformId: resolvedPlatform,
      songId: song.id,
      cover: song.cover,
      size: size,
    );
  }

  String _resolveDiscoverGridCover({
    required List<OnlinePlatform> platforms,
    required String? selectedPlatformId,
    required String itemPlatformId,
    required String cover,
  }) {
    final platformId = itemPlatformId.trim().isNotEmpty
        ? itemPlatformId.trim()
        : (selectedPlatformId ?? '').trim();
    if (platformId.isEmpty) {
      return cover;
    }
    final resolved = resolveTemplateCoverUrl(
      platforms: platforms,
      platformId: platformId,
      cover: cover,
      size: 300,
    );
    return resolved.isEmpty ? cover : resolved;
  }

  Map<String, String> _platformQualityDescriptions({
    required List<OnlinePlatform> platforms,
    required String platformId,
  }) {
    for (final platform in platforms) {
      if (platform.id == platformId) {
        return platform.qualities;
      }
    }
    return const <String, String>{};
  }

  Future<void> _downloadDiscoverSong({
    required BuildContext context,
    required WidgetRef ref,
    required SongInfo song,
    required String platformId,
    required String? artworkUrl,
    required List<PlayerQualityOption> qualities,
  }) async {
    final config = ref.read(appConfigProvider);
    final selected = await showDownloadQualitySheet(
      context: context,
      qualities: qualities,
      selectedQualityName: qualities.isEmpty ? null : qualities.first.name,
    );
    if (selected == null) {
      return;
    }
    try {
      await ref
          .read(downloadControllerProvider.notifier)
          .enqueue(
            title: song.title,
            quality: DownloadTaskQuality(
              label: selected.name,
              bitrate: selected.quality.toDouble(),
              fileExtension: selected.format.trim().toLowerCase(),
            ),
            songId: song.id,
            platform: platformId,
            artist: song.artist,
            album: song.album?.name,
            artworkUrl: artworkUrl,
          );
      if (!context.mounted) {
        return;
      }
      AppMessageService.showSuccess(
        AppI18n.format(config, 'player.download.added', <String, String>{
          'title': song.title,
        }),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      AppMessageService.showError(AppI18n.t(config, 'player.download.failed'));
    }
  }

  PlayerTrack _buildOnlineTrack({
    required String songId,
    required String title,
    required List<LinkInfo> links,
    required String artist,
    String? album,
    String? albumId,
    List<SongInfoArtistInfo> artists = const <SongInfoArtistInfo>[],
    String? mvId,
    required String artworkUrl,
    required String platformId,
  }) {
    return PlayerTrack(
      id: songId,
      title: title,
      links: links,
      artist: artist,
      album: album,
      albumId: albumId,
      artists: artists,
      mvId: mvId,
      artworkUrl: artworkUrl.isEmpty ? null : artworkUrl,
      platform: platformId,
    );
  }

  Future<void> _replaceQueueFromOnlineSong({
    required WidgetRef ref,
    required String songId,
    required String title,
    required List<LinkInfo> links,
    required String artist,
    String? album,
    String? albumId,
    List<SongInfoArtistInfo> artists = const <SongInfoArtistInfo>[],
    String? mvId,
    required String artworkUrl,
    required String platformId,
  }) async {
    final track = _buildOnlineTrack(
      songId: songId,
      title: title,
      links: links,
      artist: artist,
      album: album,
      albumId: albumId,
      artists: artists,
      mvId: mvId,
      artworkUrl: artworkUrl,
      platformId: platformId,
    );
    await ref.read(playerControllerProvider.notifier).replaceQueue(
      <PlayerTrack>[track],
    );
  }

  Future<void> _insertNextFromOnlineSong({
    required WidgetRef ref,
    required String songId,
    required String title,
    required List<LinkInfo> links,
    required String artist,
    String? album,
    String? albumId,
    List<SongInfoArtistInfo> artists = const <SongInfoArtistInfo>[],
    String? mvId,
    required String artworkUrl,
    required String platformId,
  }) async {
    final track = _buildOnlineTrack(
      songId: songId,
      title: title,
      links: links,
      artist: artist,
      album: album,
      albumId: albumId,
      artists: artists,
      mvId: mvId,
      artworkUrl: artworkUrl,
      platformId: platformId,
    );
    await ref.read(playerControllerProvider.notifier).insertNextTrack(track);
  }

  Future<void> _appendFromOnlineSong({
    required WidgetRef ref,
    required String songId,
    required String title,
    required List<LinkInfo> links,
    required String artist,
    String? album,
    String? albumId,
    List<SongInfoArtistInfo> artists = const <SongInfoArtistInfo>[],
    String? mvId,
    required String artworkUrl,
    required String platformId,
  }) async {
    final track = _buildOnlineTrack(
      songId: songId,
      title: title,
      links: links,
      artist: artist,
      album: album,
      albumId: albumId,
      artists: artists,
      mvId: mvId,
      artworkUrl: artworkUrl,
      platformId: platformId,
    );
    await ref.read(playerControllerProvider.notifier).appendTrack(track);
  }

  void _openSongSearch({
    required BuildContext context,
    required String platformId,
    required String keyword,
  }) {
    final uri = Uri(
      path: AppRoutes.onlineSearch,
      queryParameters: <String, String>{
        'platform': platformId,
        'keyword': keyword,
      },
    );
    context.push(uri.toString());
  }

  void _openAlbumDetail({
    required BuildContext context,
    required String albumId,
    required String platformId,
    required String albumTitle,
  }) {
    final localeCode = Localizations.localeOf(context).languageCode;
    context.pushAlbumDetail(
      id: albumId,
      platform: platformId,
      title: albumTitle.isEmpty
          ? AppI18n.tByLocaleCode(localeCode, 'album.fallback_title')
          : albumTitle,
    );
  }

  void _openSongComments({
    required BuildContext context,
    required WidgetRef ref,
    required String songId,
    required String platformId,
    required String title,
  }) {
    final localeCode = Localizations.localeOf(context).languageCode;
    if (!_platformSupports(
      ref: ref,
      platformId: platformId,
      featureFlag: PlatformFeatureSupportFlag.getCommentList,
    )) {
      AppMessageService.showWarning(
        AppI18n.tByLocaleCode(localeCode, 'search.comment_unsupported'),
      );
      return;
    }
    final uri = Uri(
      path: AppRoutes.onlineComments,
      queryParameters: <String, String>{
        'id': songId,
        'resource_type': 'song',
        'platform': platformId,
        'title': title,
      },
    );
    context.push(uri.toString());
  }

  void _openDiscoverSongMvDetail({
    required BuildContext context,
    required String platformId,
    required SongInfo song,
  }) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final mvId = song.mvId.trim();
    if (mvId.isEmpty || mvId == '0') {
      AppMessageService.showWarning(
        AppI18n.tByLocaleCode(localeCode, 'search.no_mv'),
      );
      return;
    }
    final uri = Uri(
      path: AppRoutes.videoDetail,
      queryParameters: <String, String>{
        'type': 'mv',
        'id': mvId,
        'platform': platformId,
        'title': song.title,
      },
    );
    context.push(uri.toString());
  }

  bool _platformSupports({
    required WidgetRef ref,
    required String platformId,
    required BigInt featureFlag,
  }) {
    final all = ref.read(onlinePlatformsProvider).value;
    if (all == null) return true;
    for (final platform in all) {
      if (platform.id != platformId) continue;
      return platform.available && platform.supports(featureFlag);
    }
    return true;
  }

  Future<void> _copyText({
    required BuildContext context,
    required String value,
    required String successLabel,
  }) async {
    final localeCode = Localizations.localeOf(context).languageCode;
    final text = value.trim();
    if (text.isEmpty) {
      AppMessageService.showWarning(
        AppI18n.tByLocaleCode(localeCode, 'search.copy_empty'),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    AppMessageService.showSuccess(successLabel);
  }

  void _openDiscoverDetailPage({
    required BuildContext context,
    required String path,
    required String id,
    required String platform,
    required String title,
  }) {
    final resolvedPlatform = platform.trim();
    if (resolvedPlatform.isEmpty) {
      throw StateError(
        'Missing selected platform when opening discover detail.',
      );
    }
    context.push(
      Uri(
        path: path,
        queryParameters: <String, String>{
          'id': id,
          'platform': resolvedPlatform,
          'title': title,
        },
      ).toString(),
    );
  }

  void _openSearchPage({
    required BuildContext context,
    required AppConfigState config,
    required String? platformId,
  }) {
    if (platformId == null || platformId.isEmpty) {
      AppMessageService.showWarning(
        AppI18n.t(config, 'home.platform_not_ready'),
      );
      return;
    }
    final uri = Uri(
      path: AppRoutes.onlineSearch,
      queryParameters: <String, String>{'platform': platformId},
    );
    context.push(uri.toString());
  }

  void _openEntry({
    required BuildContext context,
    required AppConfigState config,
    required String? platformId,
    required _DiscoverEntry entry,
  }) {
    if (platformId == null || platformId.isEmpty) {
      AppMessageService.showWarning(
        AppI18n.t(config, 'home.platform_not_ready'),
      );
      return;
    }
    final uri = switch (entry.type) {
      _DiscoverEntryType.ranking => Uri(
        path: AppRoutes.rankingList,
        queryParameters: <String, String>{'platform': platformId},
      ),
      _DiscoverEntryType.playlist => Uri(
        path: AppRoutes.playlistPlaza,
        queryParameters: <String, String>{'platform': platformId},
      ),
      _DiscoverEntryType.artist => Uri(
        path: AppRoutes.artistPlaza,
        queryParameters: <String, String>{'platform': platformId},
      ),
      _DiscoverEntryType.video => Uri(
        path: AppRoutes.videoPlaza,
        queryParameters: <String, String>{'platform': platformId},
      ),
      _DiscoverEntryType.radio => Uri(
        path: AppRoutes.radioPlaza,
        queryParameters: <String, String>{'platform': platformId},
      ),
    };
    context.push(uri.toString());
  }

  void _openPageEntry({
    required BuildContext context,
    required AppConfigState config,
    required String? platformId,
    required HomePageEntry entry,
  }) {
    final platform = platformId?.trim() ?? '';
    if (platform.isEmpty) {
      AppMessageService.showWarning(
        AppI18n.t(config, 'home.platform_not_ready'),
      );
      return;
    }
    switch (entry.targetType) {
      case HomePageEntryTargetType.songList:
        context.push(
          Uri(
            path: AppRoutes.recommendSongList,
            queryParameters: <String, String>{
              'platform': platform,
              'id': entry.targetId,
            },
          ).toString(),
        );
      case HomePageEntryTargetType.radio:
        unawaited(
          handleRadioPlayback(
            ref,
            RadioInfo(
              name: entry.title,
              id: entry.targetId,
              cover: entry.cover,
              platform: platform,
            ),
          ),
        );
      case HomePageEntryTargetType.playlist:
        context.pushPlaylistDetail(
          id: entry.targetId,
          platform: platform,
          title: entry.title,
        );
    }
  }
}

class _HomePageTabs extends StatelessWidget {
  const _HomePageTabs({
    required this.pages,
    required this.selectedPage,
    required this.config,
    required this.onSelected,
  });

  final List<HomePageKind> pages;
  final HomePageKind selectedPage;
  final AppConfigState config;
  final ValueChanged<HomePageKind> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LayoutTokens.compactPageGutter + 4,
        6,
        LayoutTokens.compactPageGutter + 4,
        4,
      ),
      child: Row(
        children: pages
            .map(
              (page) => UnderlineTab(
                label: AppI18n.t(
                  config,
                  page == HomePageKind.recommend
                      ? 'home.tab.recommend'
                      : 'home.tab.discover',
                ),
                selected: page == selectedPage,
                enabled: true,
                onTap: () => onSelected(page),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _HomePlatformError extends StatelessWidget {
  const _HomePlatformError({
    required this.message,
    required this.retryText,
    required this.onRetry,
  });

  final String message;
  final String retryText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LayoutTokens.compactPageGutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(retryText)),
          ],
        ),
      ),
    );
  }
}

class _HomeTopControls extends StatelessWidget {
  const _HomeTopControls({
    required this.config,
    required this.showEntries,
    required this.searchPlaceholderPrimary,
    required this.onSearchTap,
    required this.onEntryTap,
    required this.onParseUrl,
    this.searchPlaceholderSecondary,
  });

  final AppConfigState config;
  final bool showEntries;
  final String searchPlaceholderPrimary;
  final String? searchPlaceholderSecondary;
  final VoidCallback onSearchTap;
  final ValueChanged<_DiscoverEntry> onEntryTap;
  final VoidCallback onParseUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: HomeSearchField(
                placeholderPrimary: searchPlaceholderPrimary,
                placeholderSecondary: searchPlaceholderSecondary,
                onTap: onSearchTap,
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onParseUrl,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.link_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (showEntries) ...<Widget>[
          const SizedBox(height: 14),
          _EntryRow(config: config, onTapEntry: onEntryTap),
        ],
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.config, required this.onTapEntry});

  final AppConfigState config;
  final ValueChanged<_DiscoverEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _entries
          .asMap()
          .entries
          .map((entry) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: entry.key == _entries.length - 1 ? 0 : 8,
                ),
                child: _EntryTile(
                  iconRole: entry.value.iconRole,
                  title: AppI18n.t(config, entry.value.titleKey),
                  onTap: () => onTapEntry(entry.value),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.iconRole, required this.title, this.onTap});

  final AppSkinIconRole iconRole;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppSkinIcon(
                role: iconRole,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBackground extends StatelessWidget {
  const _HomeBackground();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSkinLegacyPageBackground(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                theme.colorScheme.primaryContainer.withValues(alpha: 0.10),
                theme.colorScheme.surface.withValues(alpha: 0.98),
                theme.scaffoldBackgroundColor,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformBar extends StatelessWidget {
  const _PlatformBar({
    required this.selectedPlatformId,
    required this.onSelected,
    required this.chips,
  });

  final String? selectedPlatformId;
  final ValueChanged<String> onSelected;
  final List<_PlatformChipData> chips;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips
              .map(
                (chip) => _UnderlineTab(
                  label: chip.label,
                  selected: chip.id == selectedPlatformId,
                  enabled: true,
                  onTap: () => onSelected(chip.id),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _UnderlineTab extends StatelessWidget {
  const _UnderlineTab({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return UnderlineTab(
      label: label,
      selected: selected,
      enabled: enabled,
      onTap: onTap,
    );
  }
}

class _PlatformChipData {
  const _PlatformChipData({required this.id, required this.label});

  final String id;
  final String label;
}

class _DiscoverEntry {
  const _DiscoverEntry({
    required this.type,
    required this.iconRole,
    required this.titleKey,
  });

  final _DiscoverEntryType type;
  final AppSkinIconRole iconRole;
  final String titleKey;
}
