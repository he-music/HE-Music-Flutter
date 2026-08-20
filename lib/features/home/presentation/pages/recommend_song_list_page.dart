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
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/detail_description_sheet.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/music_detail_slivers.dart';
import '../../../../shared/widgets/song_batch_action_bar.dart';
import '../../../../shared/widgets/song_info_list_section.dart';
import '../../../player/domain/entities/player_queue_source.dart';
import '../../domain/entities/recommend_song_list_info.dart';
import '../../domain/entities/recommend_song_list_request.dart';
import '../../domain/entities/recommend_song_list_state.dart';
import '../providers/home_page_providers.dart';

class RecommendSongListPage extends ConsumerStatefulWidget {
  const RecommendSongListPage({
    required this.id,
    required this.platform,
    super.key,
  });

  final String id;
  final String platform;

  @override
  ConsumerState<RecommendSongListPage> createState() =>
      _RecommendSongListPageState();
}

class _RecommendSongListPageState extends ConsumerState<RecommendSongListPage> {
  late final RecommendSongListRequest _request;
  bool _isBatchMode = false;
  bool _submittingBatch = false;
  Set<String> _selectedSongKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _request = RecommendSongListRequest(
      id: widget.id,
      platform: widget.platform,
    );
    Future.microtask(() {
      ref
          .read(recommendSongListControllerProvider(_request.cacheKey).notifier)
          .initialize(_request);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = recommendSongListControllerProvider(_request.cacheKey);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final info = state.info;
    if (info == null) {
      return DetailPageShell(
        child: _buildPlaceholder(
          state,
          onRetry: () => controller.retry(_request),
        ),
      );
    }
    final songActions = _buildSongActions(info);
    return DetailPageShell(
      onBackRequested: _isBatchMode ? () => _setBatchMode(false) : null,
      bottomBar: _isBatchMode
          ? SongBatchActionBar(
              enabled: songActions
                  .collectSelectedSongs(info.songs, _selectedSongKeys)
                  .isNotEmpty,
              loading: _submittingBatch,
              onPlayPressed: () =>
                  unawaited(_playSelectedSongs(songActions, info.songs)),
              onAddToQueuePressed: () => unawaited(
                _appendSelectedSongsToQueue(songActions, info.songs),
              ),
              onAddToPlaylistPressed: () => unawaited(
                _addSelectedSongsToPlaylist(songActions, info.songs),
              ),
            )
          : null,
      child: _buildDetail(info, songActions),
    );
  }

  Widget _buildPlaceholder(
    RecommendSongListState state, {
    required VoidCallback onRetry,
  }) {
    if (state.loading) {
      return DetailLoadingBody(
        title: AppI18n.t(ref.read(appConfigProvider), 'home.tab.recommend'),
      );
    }
    return DetailErrorBody(
      message:
          state.errorMessage ??
          AppI18n.t(ref.read(appConfigProvider), 'home.recommend.empty'),
      onRetry: onRetry,
    );
  }

  DetailSongActionHandler _buildSongActions(RecommendSongListInfo info) {
    return DetailSongActionHandler(
      ref: ref,
      queueSource: PlayerQueueSource(
        routePath: AppRoutes.recommendSongList,
        queryParameters: <String, String>{
          'platform': widget.platform,
          'id': widget.id,
        },
        title: info.title,
      ),
      platformIdResolver: _resolveSongPlatform,
    );
  }

  String _resolveSongPlatform(SongInfo song) {
    final platform = song.platform.trim();
    return platform.isEmpty ? widget.platform : platform;
  }

  Widget _buildDetail(
    RecommendSongListInfo info,
    DetailSongActionHandler songActions,
  ) {
    final songs = info.songs;
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
        MusicDetailSliverAppBar(
          title: info.title,
          subtitle: '',
          coverUrl: info.cover,
          description: info.description,
          metaItems: <MusicDetailMetaItem>[
            MusicDetailMetaItem(
              icon: Icons.music_note_rounded,
              label: AppI18n.format(
                ref.read(appConfigProvider),
                'detail.track_count',
                <String, String>{'count': '${songs.length}'},
              ),
            ),
          ],
          onPreviewCover: () => showDetailCoverPreview(
            context: context,
            ref: ref,
            title: info.title,
            imageUrl: info.cover,
          ),
          onBack: _isBatchMode
              ? () => _setBatchMode(false)
              : () => context.appPopOrGo(),
          onShowDescription: () => showDetailDescriptionSheet(
            context,
            title: info.title,
            text: info.description,
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: MusicDetailPlayAllHeader(
            countText: AppI18n.format(
              ref.read(appConfigProvider),
              'detail.play_all_count',
              <String, String>{'count': '${songs.length}'},
            ),
            enabled: songs.isNotEmpty,
            onPlayAll: () => unawaited(songActions.playAll(context, songs)),
            onBatchAction: songs.isEmpty ? null : () => _setBatchMode(true),
            batchMode: _isBatchMode,
            selectedCount: songActions
                .collectSelectedSongs(songs, _selectedSongKeys)
                .length,
            allSelected: areAllLoadedSongsSelected(
              songs,
              _selectedSongKeys,
              songIdOf: (song) => song.id,
              platformOf: _resolveSongPlatform,
            ),
            onSelectAll: songs.isEmpty
                ? null
                : () => _selectAllLoadedSongs(songs),
            onCancelBatch: _isBatchMode ? () => _setBatchMode(false) : null,
          ),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutTokens.listItemInnerGutter,
        ),
        child: SongInfoListSection(
          songs: songs,
          resolveSongCover: songActions.resolveCoverUrl,
          resolvePlatformId: songActions.resolvePlatformId,
          onTapSong: (song, coverUrl, index) =>
              songActions.playAll(context, songs, startIndex: index),
          onLikeSong: songActions.toggleSongFavorite,
          onMoreSong: (song, coverUrl) => songActions.showSongActions(
            context: context,
            song: song,
            coverUrl: coverUrl,
          ),
          enablePaging: false,
          empty: Center(
            child: Text(
              AppI18n.t(ref.read(appConfigProvider), 'detail.empty_songs'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
          batchMode: _isBatchMode,
          selectedSongKeys: _selectedSongKeys,
          onToggleSongSelection: _toggleSongSelection,
        ),
      ),
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

  void _toggleSongSelection(SongInfo song) {
    final key = buildSongBatchKey(
      songId: song.id,
      platform: _resolveSongPlatform(song),
    );
    setState(() {
      if (_selectedSongKeys.contains(key)) {
        _selectedSongKeys.remove(key);
      } else {
        _selectedSongKeys.add(key);
      }
    });
  }

  void _selectAllLoadedSongs(List<SongInfo> songs) {
    final nextSelection = buildLoadedSongBatchKeys(
      songs,
      songIdOf: (song) => song.id,
      platformOf: _resolveSongPlatform,
    );
    setState(() {
      _selectedSongKeys =
          nextSelection.isNotEmpty &&
              nextSelection.every(_selectedSongKeys.contains)
          ? <String>{}
          : nextSelection;
    });
  }

  Future<void> _playSelectedSongs(
    DetailSongActionHandler songActions,
    List<SongInfo> songs,
  ) async {
    final success = await songActions.playSelectedSongs(
      context,
      songs: songs,
      selectedSongKeys: _selectedSongKeys,
      submittingBatch: _submittingBatch,
    );
    if (mounted && success) {
      _setBatchMode(false);
    }
  }

  Future<void> _appendSelectedSongsToQueue(
    DetailSongActionHandler songActions,
    List<SongInfo> songs,
  ) async {
    setState(() {
      _submittingBatch = true;
    });
    final success = await songActions.appendSelectedSongsToQueue(
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

  Future<void> _addSelectedSongsToPlaylist(
    DetailSongActionHandler songActions,
    List<SongInfo> songs,
  ) async {
    setState(() {
      _submittingBatch = true;
    });
    final success = await songActions.addSelectedSongsToPlaylist(
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
