import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/app_message_service.dart';
import '../../../../../app/config/app_config_controller.dart';
import '../../../../../app/i18n/app_i18n.dart';
import '../../../../../app/router/app_routes.dart';
import '../../../../../shared/helpers/detail_song_action_handler.dart';
import '../../../../../shared/helpers/song_batch_helpers.dart';
import '../../../../../shared/models/he_music_models.dart';
import '../../../../../shared/utils/favorite_song_key.dart';
import '../../../../../shared/widgets/app_back_button.dart';
import '../../../../../shared/widgets/detail_page_shell.dart';
import '../../../../../shared/widgets/online_platform_tabs.dart';
import '../../../../../shared/widgets/plaza_loading_skeleton.dart';
import '../../../../../shared/widgets/song_batch_action_bar.dart';
import '../../../../../shared/widgets/song_info_list_section.dart';
import '../../../../../shared/widgets/underline_tab.dart';
import '../../../../my/presentation/providers/favorite_song_status_providers.dart';
import '../../../../online/domain/entities/online_platform.dart';
import '../../../../player/presentation/providers/player_providers.dart';
import '../providers/new_song_page_providers.dart';

class NewSongPage extends ConsumerStatefulWidget {
  const NewSongPage({this.initialPlatform, this.initialTabId, super.key});

  final String? initialPlatform;
  final String? initialTabId;

  @override
  ConsumerState<NewSongPage> createState() => _NewSongPageState();
}

class _NewSongPageState extends ConsumerState<NewSongPage> {
  late final DetailSongActionHandler _songActions;
  bool _isBatchMode = false;
  bool _submittingBatch = false;
  Set<String> _selectedSongKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _songActions = DetailSongActionHandler(
      ref: ref,
      platformIdResolver: (song) {
        final platformId = song.platform.trim();
        return platformId.isNotEmpty ? platformId : _selectedPlatformId;
      },
      onWatchMv: _openNewSongMvDetail,
    );
    Future.microtask(() {
      ref
          .read(newSongPageControllerProvider.notifier)
          .initialize(
            preferredPlatformId: widget.initialPlatform,
            preferredTabId: widget.initialTabId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newSongPageControllerProvider);
    final controller = ref.read(newSongPageControllerProvider.notifier);
    final currentTrack = ref.watch(
      playerControllerProvider.select((playback) => playback.currentTrack),
    );
    final favoriteSongKeys = ref.watch(
      favoriteSongStatusProvider.select((favorite) => favorite.songKeys),
    );

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
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(AppI18n.t(ref.read(appConfigProvider), 'new_song.title')),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: state.tabsLoading && state.platforms.isEmpty
                  ? const PlazaPlatformTabsSkeleton()
                  : OnlinePlatformTabs(
                      platforms: state.platforms,
                      selectedId: state.selectedPlatformId,
                      requiredFeatureFlag:
                          PlatformFeatureSupportFlag.getNewSongList,
                      onSelected: controller.selectPlatform,
                    ),
            ),
            const Divider(height: 1),
            if (state.tabsLoading && state.tabs.isEmpty)
              const UnderlineTabsSkeleton()
            else
              _ReleaseTabBar(
                labels: state.tabs
                    .map(
                      (item) => _ReleaseTabData(id: item.id, name: item.name),
                    )
                    .toList(growable: false),
                selectedId: state.selectedTabId,
                onSelected: controller.selectTab,
              ),
            const Divider(height: 1),
            Expanded(
              child: SongInfoListSection(
                songs: state.songs,
                currentTrack: currentTrack,
                resolveSongCover: _songActions.resolveCoverUrl,
                resolvePlatformId: _songActions.resolvePlatformId,
                isSongLiked: (song) {
                  final platformId = _songActions.resolvePlatformId(song);
                  if (platformId.isEmpty) {
                    return false;
                  }
                  return favoriteSongKeys.contains(
                    buildFavoriteSongKey(songId: song.id, platform: platformId),
                  );
                },
                artistAlbumTextBuilder: (song) => song.artistAlbumText,
                subtitleTextBuilder: (song) => song.displaySubtitle,
                onTapSong: (song, coverUrl, index) => _songActions.playAll(
                  context,
                  state.songs,
                  startIndex: index,
                ),
                onLikeSong: (song) => _songActions.toggleSongFavorite(song),
                onMoreSong: (song, coverUrl) => _songActions.showSongActions(
                  context: context,
                  song: song,
                  coverUrl: coverUrl,
                ),
                initialLoading:
                    state.songs.isEmpty &&
                    (state.tabsLoading || state.songsLoading),
                errorMessage: state.songsErrorMessage,
                onRetry: controller.retry,
                enablePaging: true,
                loadingMore: state.loadingMore,
                hasMore: state.hasMore,
                onLoadMore: controller.loadMore,
                empty: Center(
                  child: Text(
                    AppI18n.t(ref.read(appConfigProvider), 'new_song.empty'),
                  ),
                ),
                countText: AppI18n.format(
                  ref.read(appConfigProvider),
                  'detail.play_all_count',
                  <String, String>{'count': '${state.songs.length}'},
                ),
                onPlayAll: state.songs.isEmpty
                    ? null
                    : () => _songActions.playAll(context, state.songs),
                batchMode: _isBatchMode,
                selectedSongKeys: _selectedSongKeys,
                selectedCount: _songActions
                    .collectSelectedSongs(state.songs, _selectedSongKeys)
                    .length,
                allSelected: areAllLoadedSongsSelected(
                  state.songs,
                  _selectedSongKeys,
                  songIdOf: (song) => song.id,
                  platformOf: _songActions.resolvePlatformId,
                ),
                onEnterBatchMode: () => _setBatchMode(true),
                onCancelBatch: () => _setBatchMode(false),
                onSelectAllLoaded: () => _selectAllLoadedSongs(state.songs),
                onToggleSongSelection: _toggleSongSelection,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _selectedPlatformId {
    return ref.read(newSongPageControllerProvider).selectedPlatformId?.trim() ??
        '';
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
      platform: _songActions.resolvePlatformId(song),
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
      platformOf: _songActions.resolvePlatformId,
    );
    setState(() {
      _selectedSongKeys =
          nextSelection.isNotEmpty &&
              nextSelection.every(_selectedSongKeys.contains)
          ? <String>{}
          : nextSelection;
    });
  }

  Future<void> _playSelectedSongs(List<SongInfo> songs) async {
    final success = await _songActions.playSelectedSongs(
      context,
      songs: songs,
      selectedSongKeys: _selectedSongKeys,
      submittingBatch: _submittingBatch,
    );
    if (!mounted || !success) {
      return;
    }
    _setBatchMode(false);
  }

  Future<void> _appendSelectedSongsToQueue(List<SongInfo> songs) async {
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

  Future<void> _addSelectedSongsToPlaylist(List<SongInfo> songs) async {
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

  void _openNewSongMvDetail(
    BuildContext context,
    SongInfo song,
    String platformId,
  ) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final mvId = song.mvId.trim();
    if (mvId.isEmpty || mvId == '0') {
      AppMessageService.showWarning(
        AppI18n.tByLocaleCode(localeCode, 'search.no_mv'),
      );
      return;
    }
    context.push(
      Uri(
        path: AppRoutes.videoDetail,
        queryParameters: <String, String>{
          'type': 'mv',
          'id': mvId,
          'platform': platformId,
          'title': song.title,
        },
      ).toString(),
    );
  }
}

class _ReleaseTabData {
  const _ReleaseTabData({required this.id, required this.name});

  final String id;
  final String name;
}

class _ReleaseTabBar extends StatelessWidget {
  const _ReleaseTabBar({
    required this.labels,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_ReleaseTabData> labels;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: labels
            .map(
              (item) => UnderlineTab(
                label: item.name,
                selected: item.id == selectedId,
                enabled: true,
                onTap: () => onSelected(item.id),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
