import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/helpers/detail_cover_preview_helper.dart';
import '../../../../shared/helpers/detail_song_action_handler.dart';
import '../../../../shared/helpers/song_batch_helpers.dart';
import '../../../../shared/utils/favorite_song_key.dart';
import '../../../../shared/widgets/detail_description_sheet.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/music_detail_slivers.dart';
import '../../../../shared/widgets/song_info_list_section.dart';
import '../../../../shared/widgets/song_batch_action_bar.dart';
import '../../../my/presentation/providers/favorite_song_status_providers.dart';
import '../../../player/domain/entities/player_queue_source.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/ranking_detail_request.dart';
import '../../domain/entities/ranking_song.dart';
import '../controllers/ranking_detail_controller.dart';
import '../providers/ranking_providers.dart';

class RankingDetailPage extends ConsumerStatefulWidget {
  const RankingDetailPage({
    required this.id,
    required this.platform,
    this.title,
    super.key,
  });

  final String id;
  final String platform;
  final String? title;

  @override
  ConsumerState<RankingDetailPage> createState() => _RankingDetailPageState();
}

class _RankingDetailPageState extends ConsumerState<RankingDetailPage> {
  late final RankingDetailRequest _request;
  late final DetailSongActionHandler _songActions;
  bool _isBatchMode = false;
  bool _submittingBatch = false;
  Set<String> _selectedSongKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _request = RankingDetailRequest(
      id: widget.id,
      platform: widget.platform,
      title: widget.title,
    );
    _songActions = DetailSongActionHandler(
      ref: ref,
      queueSource: PlayerQueueSource(
        routePath: AppRoutes.rankingDetail,
        queryParameters: <String, String>{
          'id': widget.id,
          'platform': widget.platform,
          if ((widget.title ?? '').trim().isNotEmpty) 'title': widget.title!,
        },
        title:
            widget.title ??
            AppI18n.t(ref.read(appConfigProvider), 'ranking.fallback_title'),
      ),
    );
    Future.microtask(() {
      ref
          .read(rankingDetailControllerProvider(_request.cacheKey).notifier)
          .initialize(_request);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = rankingDetailControllerProvider(_request.cacheKey);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final config = ref.watch(appConfigProvider);
    final title =
        state.detail?.info.name ??
        widget.title ??
        AppI18n.t(config, 'ranking.fallback_title');

    return DetailPageShell(
      bottomBar: _isBatchMode
          ? SongBatchActionBar(
              enabled: _songActions
                  .collectSelectedSongs(state.songs, _selectedSongKeys)
                  .isNotEmpty,
              loading: _submittingBatch,
              onPlayPressed: () => unawaited(_playSelectedSongs(state.songs)),
              onAddToQueuePressed: () =>
                  unawaited(_appendSelectedSongsToQueue(state.songs)),
              onAddToPlaylistPressed: () =>
                  unawaited(_addSelectedSongsToPlaylist(state.songs)),
            )
          : null,
      child: state.loading
          ? DetailLoadingBody(
              title:
                  widget.title ?? AppI18n.t(config, 'ranking.fallback_title'),
            )
          : state.errorMessage != null
          ? DetailErrorBody(
              message: state.errorMessage!,
              onRetry: () => controller.retry(_request),
            )
          : _Body(
              request: _request,
              state: state,
              onLoadMore: () => controller.loadMore(_request),
              onPreviewCover: (title, coverUrl) =>
                  _previewCover(title, coverUrl),
              onPlaySong: (song, coverUrl, index) =>
                  _songActions.playAll(context, state.songs, startIndex: index),
              resolveSongCover: _songActions.resolveCoverUrl,
              resolvePlatformId: _songActions.resolvePlatformId,
              isSongLiked: (song) => ref.read(
                favoriteSongStatusProvider.select(
                  (favorite) => favorite.songKeys.contains(
                    buildFavoriteSongKey(
                      songId: song.id,
                      platform: _songActions.resolvePlatformId(song),
                    ),
                  ),
                ),
              ),
              onLikeSong: _songActions.toggleSongFavorite,
              onMoreSong: (song, coverUrl) => _songActions.showSongActions(
                context: context,
                song: song,
                coverUrl: coverUrl,
              ),
              onPlayAll: () => _songActions.playAll(context, state.songs),
              batchMode: _isBatchMode,
              selectedSongKeys: _selectedSongKeys,
              selectedCount: _songActions
                  .collectSelectedSongs(state.songs, _selectedSongKeys)
                  .length,
              allSelected: areAllLoadedSongsSelected(
                state.songs,
                _selectedSongKeys,
                songIdOf: (song) => song.id,
                platformOf: (song) => song.platform,
              ),
              onEnterBatchMode: () => _setBatchMode(true),
              onCancelBatch: () => _setBatchMode(false),
              onSelectAllLoaded: () => _selectAllLoadedSongs(state.songs),
              onToggleSongSelection: _toggleSongSelection,
              onShowDescription: (text) =>
                  showDetailDescriptionSheet(context, title: title, text: text),
            ),
    );
  }

  Future<void> _previewCover(String title, String coverUrl) {
    return showDetailCoverPreview(
      context: context,
      ref: ref,
      title: title,
      imageUrl: coverUrl,
    );
  }

  void _setBatchMode(bool enabled) {
    setState(() {
      _isBatchMode = enabled;
      _submittingBatch = false;
      if (!enabled) {
        _selectedSongKeys = <String>{};
      }
    });
  }

  void _toggleSongSelection(RankingSong song) {
    final key = buildSongBatchKey(songId: song.id, platform: song.platform);
    setState(() {
      if (_selectedSongKeys.contains(key)) {
        _selectedSongKeys.remove(key);
      } else {
        _selectedSongKeys.add(key);
      }
    });
  }

  void _selectAllLoadedSongs(List<RankingSong> songs) {
    final nextSelection = buildLoadedSongBatchKeys(
      songs,
      songIdOf: (song) => song.id,
      platformOf: (song) => song.platform,
    );
    setState(() {
      _selectedSongKeys =
          nextSelection.isNotEmpty &&
              nextSelection.every(_selectedSongKeys.contains)
          ? <String>{}
          : nextSelection;
    });
  }

  Future<void> _playSelectedSongs(List<RankingSong> songs) async {
    final success = await _songActions.playSelectedSongs(
      context,
      songs: songs,
      selectedSongKeys: _selectedSongKeys,
      submittingBatch: _submittingBatch,
    );
    if (mounted && success) {
      _setBatchMode(false);
    }
  }

  Future<void> _appendSelectedSongsToQueue(List<RankingSong> songs) async {
    setState(() {
      _submittingBatch = true;
    });
    final success = await _songActions.appendSelectedSongsToQueue(
      context,
      songs: songs,
      selectedSongKeys: _selectedSongKeys,
      submittingBatch: false,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _submittingBatch = false;
    });
    if (success) {
      _setBatchMode(false);
    }
  }

  Future<void> _addSelectedSongsToPlaylist(List<RankingSong> songs) async {
    setState(() {
      _submittingBatch = true;
    });
    final success = await _songActions.addSelectedSongsToPlaylist(
      context,
      songs: songs,
      selectedSongKeys: _selectedSongKeys,
      submittingBatch: false,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _submittingBatch = false;
    });
    if (success) {
      _setBatchMode(false);
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.request,
    required this.state,
    required this.onLoadMore,
    required this.onPreviewCover,
    required this.onPlaySong,
    required this.resolveSongCover,
    required this.resolvePlatformId,
    required this.isSongLiked,
    required this.onLikeSong,
    required this.onMoreSong,
    required this.onPlayAll,
    required this.batchMode,
    required this.selectedSongKeys,
    required this.selectedCount,
    required this.allSelected,
    required this.onEnterBatchMode,
    required this.onCancelBatch,
    required this.onSelectAllLoaded,
    required this.onToggleSongSelection,
    required this.onShowDescription,
  });

  final RankingDetailRequest request;
  final RankingDetailState state;
  final Future<void> Function() onLoadMore;
  final void Function(String title, String coverUrl) onPreviewCover;
  final void Function(RankingSong, String coverUrl, int index) onPlaySong;
  final String Function(RankingSong song) resolveSongCover;
  final String Function(RankingSong song) resolvePlatformId;
  final bool Function(RankingSong song) isSongLiked;
  final Future<void> Function(RankingSong song) onLikeSong;
  final void Function(RankingSong, String coverUrl) onMoreSong;
  final VoidCallback onPlayAll;
  final bool batchMode;
  final Set<String> selectedSongKeys;
  final int selectedCount;
  final bool allSelected;
  final VoidCallback onEnterBatchMode;
  final VoidCallback onCancelBatch;
  final VoidCallback onSelectAllLoaded;
  final void Function(RankingSong song) onToggleSongSelection;
  final ValueChanged<String> onShowDescription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = state.detail;
    final config = ref.watch(appConfigProvider);
    final currentTrack = ref.watch(
      playerControllerProvider.select((player) => player.currentTrack),
    );
    if (detail == null) {
      return const Center(child: Text('No detail content.'));
    }
    final coverUrl = detail.info.coverUrl;
    final subtitle = detail.totalCount > 0
        ? AppI18n.format(config, 'ranking.track_count', <String, String>{
            'count': '${detail.totalCount}',
          })
        : '';

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return <Widget>[
          MusicDetailSliverAppBar(
            title: detail.info.name,
            subtitle: subtitle,
            coverUrl: coverUrl,
            description: detail.description,
            onPreviewCover: () => onPreviewCover(detail.info.name, coverUrl),
            onBack: () => context.appPopOrGo(),
            onShowDescription: () => onShowDescription(detail.description),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: MusicDetailPlayAllHeader(
              countText: AppI18n.format(
                config,
                'detail.play_all_count',
                <String, String>{'count': '${state.songs.length}'},
              ),
              onPlayAll: onPlayAll,
              onBatchAction: state.songs.isEmpty ? null : onEnterBatchMode,
              batchMode: batchMode,
              selectedCount: selectedCount,
              allSelected: allSelected,
              onSelectAll: state.songs.isEmpty ? null : onSelectAllLoaded,
              onCancelBatch: batchMode ? onCancelBatch : null,
            ),
          ),
        ];
      },
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          LayoutTokens.listItemInnerGutter,
          0,
          LayoutTokens.listItemInnerGutter,
          0,
        ),
        child: SongInfoListSection(
          songs: state.songs,
          currentTrack: currentTrack,
          resolveSongCover: resolveSongCover,
          resolvePlatformId: resolvePlatformId,
          isSongLiked: isSongLiked,
          onTapSong: onPlaySong,
          onLikeSong: onLikeSong,
          onMoreSong: onMoreSong,
          initialLoading: state.loading && state.songs.isEmpty,
          enablePaging: true,
          loadingMore: state.loadingMore,
          hasMore: state.hasMore,
          onLoadMore: onLoadMore,
          empty: Center(
            child: Text(
              AppI18n.t(config, 'detail.empty_songs'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
          batchMode: batchMode,
          selectedSongKeys: selectedSongKeys,
          onToggleSongSelection: onToggleSongSelection,
        ),
      ),
    );
  }
}
