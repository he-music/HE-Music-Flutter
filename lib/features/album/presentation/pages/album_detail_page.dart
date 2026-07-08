import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/network/network_error_message.dart';
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
import '../../../my/presentation/providers/favorite_collection_status_providers.dart';
import '../../../my/presentation/providers/favorite_song_status_providers.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../player/domain/entities/player_queue_source.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/album_detail_content.dart';
import '../../domain/entities/album_detail_request.dart';
import '../../domain/entities/album_detail_song.dart';
import '../../domain/entities/album_detail_state.dart';
import '../providers/album_detail_providers.dart';

class AlbumDetailPage extends ConsumerStatefulWidget {
  const AlbumDetailPage({
    required this.id,
    required this.platform,
    required this.title,
    super.key,
  });

  final String id;
  final String platform;
  final String title;

  @override
  ConsumerState<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends ConsumerState<AlbumDetailPage> {
  late final AlbumDetailRequest _request;
  late final DetailSongActionHandler _songActions;
  bool _isBatchMode = false;
  bool _submittingBatch = false;
  Set<String> _selectedSongKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _request = AlbumDetailRequest(
      id: widget.id,
      platform: widget.platform,
      title: widget.title,
    );
    _songActions = DetailSongActionHandler(
      ref: ref,
      queueSource: PlayerQueueSource(
        routePath: AppRoutes.albumDetail,
        queryParameters: <String, String>{
          'id': widget.id,
          'platform': widget.platform,
          'title': widget.title,
        },
        title: widget.title,
      ),
    );
    Future.microtask(() {
      ref.read(albumDetailControllerProvider.notifier).initialize(_request);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(albumDetailControllerProvider);
    final controller = ref.read(albumDetailControllerProvider.notifier);
    final content = state.content;

    if (content == null) {
      if (state.loading) {
        return DetailPageShell(child: DetailLoadingBody(title: widget.title));
      }
      return DetailPageShell(
        child: _buildPlaceholderBody(
          context: context,
          state: state,
          onRetry: () => controller.retry(_request),
        ),
      );
    }

    return DetailPageShell(
      bottomBar: _isBatchMode
          ? SongBatchActionBar(
              enabled: _songActions
                  .collectSelectedSongs(content.songs, _selectedSongKeys)
                  .isNotEmpty,
              loading: _submittingBatch,
              onPlayPressed: () => unawaited(_playSelectedSongs(content.songs)),
              onAddToQueuePressed: () =>
                  unawaited(_appendSelectedSongsToQueue(content.songs)),
              onAddToPlaylistPressed: () =>
                  unawaited(_addSelectedSongsToPlaylist(content.songs)),
            )
          : null,
      child: _buildDetailBody(context: context, content: content),
    );
  }

  Widget _buildPlaceholderBody({
    required BuildContext context,
    required AlbumDetailState state,
    required VoidCallback onRetry,
  }) {
    if (state.loading) {
      return DetailLoadingBody(title: widget.title);
    }
    if (state.errorMessage != null) {
      return DetailErrorBody(message: state.errorMessage!, onRetry: onRetry);
    }
    return Center(
      child: Text(
        AppI18n.t(ref.read(appConfigProvider), 'detail.no_album_content'),
      ),
    );
  }

  Widget _buildDetailBody({
    required BuildContext context,
    required AlbumDetailContent content,
  }) {
    final title = content.title.trim().isEmpty ? widget.title : content.title;
    final subtitle = content.subtitle.trim();
    final coverUrl = content.coverUrl.trim();
    final description = content.description;
    final songs = content.songs;
    final currentTrack = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final isFavorited = ref.watch(
      favoriteCollectionStatusProvider.select(
        (state) => state.albumKeys.contains(
          '${widget.id.trim()}|${widget.platform.trim()}',
        ),
      ),
    );
    final metaItems = _buildMetaItems(content, songs.length);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return <Widget>[
          MusicDetailSliverAppBar(
            title: title,
            subtitle: subtitle,
            coverUrl: coverUrl,
            description: description,
            metaItems: metaItems,
            actions: <Widget>[
              IconButton(
                onPressed: () => unawaited(
                  _toggleAlbumFavorite(isFavorited, content: content),
                ),
                icon: Icon(
                  isFavorited
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorited
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                tooltip: isFavorited
                    ? AppI18n.t(
                        ref.read(appConfigProvider),
                        'detail.favorite.remove_album',
                      )
                    : AppI18n.t(
                        ref.read(appConfigProvider),
                        'detail.favorite.add_album',
                      ),
              ),
            ],
            onPreviewCover: () => _previewCover(title, coverUrl),
            onBack: () => context.appPopOrGo(),
            onShowDescription: () => showDetailDescriptionSheet(
              context,
              title: title,
              text: description,
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
              onPlayAll: () => _songActions.playAll(context, songs),
              onBatchAction: songs.isEmpty ? null : () => _setBatchMode(true),
              batchMode: _isBatchMode,
              selectedCount: _songActions
                  .collectSelectedSongs(songs, _selectedSongKeys)
                  .length,
              allSelected: areAllLoadedSongsSelected(
                songs,
                _selectedSongKeys,
                songIdOf: (song) => song.id,
                platformOf: (song) => song.platform,
              ),
              onSelectAll: songs.isEmpty
                  ? null
                  : () => _selectAllLoadedSongs(songs),
              onCancelBatch: _isBatchMode ? () => _setBatchMode(false) : null,
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
          songs: songs,
          currentTrack: currentTrack,
          resolveSongCover: _songActions.resolveCoverUrl,
          resolvePlatformId: _songActions.resolvePlatformId,
          isSongLiked: (song) => ref.watch(
            favoriteSongStatusProvider.select(
              (state) => state.songKeys.contains(
                buildFavoriteSongKey(
                  songId: song.id,
                  platform: _songActions.resolvePlatformId(song),
                ),
              ),
            ),
          ),
          onTapSong: (song, coverUrl, index) =>
              _songActions.playAll(context, songs, startIndex: index),
          onLikeSong: (song) => _songActions.toggleSongFavorite(song),
          onMoreSong: (song, coverUrl) => _songActions.showSongActions(
            context: context,
            song: song,
            coverUrl: coverUrl,
          ),
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

  List<MusicDetailMetaItem> _buildMetaItems(
    AlbumDetailContent content,
    int songCount,
  ) {
    final items = <MusicDetailMetaItem>[
      MusicDetailMetaItem(
        icon: Icons.music_note_rounded,
        label: AppI18n.format(
          ref.read(appConfigProvider),
          'detail.track_count',
          <String, String>{'count': '$songCount'},
        ),
      ),
    ];
    final publishDate = _formatPublishDate(content.publishTime);
    if (publishDate.isNotEmpty) {
      items.add(
        MusicDetailMetaItem(icon: Icons.event_rounded, label: publishDate),
      );
    }
    return items;
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

  void _toggleSongSelection(AlbumDetailSong song) {
    final key = buildSongBatchKey(songId: song.id, platform: song.platform);
    setState(() {
      if (_selectedSongKeys.contains(key)) {
        _selectedSongKeys.remove(key);
      } else {
        _selectedSongKeys.add(key);
      }
    });
  }

  void _selectAllLoadedSongs(List<AlbumDetailSong> songs) {
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

  Future<void> _playSelectedSongs(List<AlbumDetailSong> songs) async {
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

  Future<void> _appendSelectedSongsToQueue(List<AlbumDetailSong> songs) async {
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

  Future<void> _addSelectedSongsToPlaylist(List<AlbumDetailSong> songs) async {
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

  Future<void> _toggleAlbumFavorite(
    bool isFavorited, {
    required AlbumDetailContent content,
  }) async {
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .toggleAlbumFavorite(
            albumId: widget.id,
            platform: widget.platform,
            name: content.title,
            cover: content.coverUrl,
            artists: content.info.artists
                .map(
                  (item) => <String, dynamic>{'id': item.id, 'name': item.name},
                )
                .toList(growable: false),
            like: !isFavorited,
          );
    } catch (error) {
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error) ??
            AppI18n.t(
              ref.read(appConfigProvider),
              'detail.favorite.album_failed',
            ),
      );
    }
  }
}
