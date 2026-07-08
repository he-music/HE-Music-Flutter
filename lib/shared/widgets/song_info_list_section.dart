import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../helpers/current_track_helper.dart';
import '../helpers/song_batch_helpers.dart';
import '../models/he_music_models.dart';
import '../../features/player/domain/entities/player_track.dart';
import 'music_detail_slivers.dart';
import 'online_song_list_item.dart';
import 'song_list_component.dart';

typedef SongInfoTextBuilder = String Function(SongInfo song);
typedef SongInfoNullableTextBuilder = String? Function(SongInfo song);
typedef SongInfoTapCallback =
    FutureOr<void> Function(SongInfo song, String coverUrl, int index);
typedef SongInfoActionCallback = FutureOr<void> Function(SongInfo song);
typedef SongInfoMoreCallback = void Function(SongInfo song, String coverUrl);

class SongInfoListSection extends StatelessWidget {
  const SongInfoListSection({
    required this.songs,
    required this.currentTrack,
    required this.resolveSongCover,
    required this.resolvePlatformId,
    required this.isSongLiked,
    required this.onTapSong,
    required this.onLikeSong,
    required this.onMoreSong,
    this.artistAlbumTextBuilder,
    this.subtitleTextBuilder,
    this.initialLoading = false,
    this.errorMessage,
    this.onRetry,
    this.enablePaging = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.onLoadMore,
    this.empty,
    this.countText,
    this.onPlayAll,
    this.batchMode = false,
    this.selectedSongKeys = const <String>{},
    this.selectedCount = 0,
    this.allSelected = false,
    this.onEnterBatchMode,
    this.onCancelBatch,
    this.onSelectAllLoaded,
    this.onToggleSongSelection,
    super.key,
  });

  final List<SongInfo> songs;
  final PlayerTrack? currentTrack;
  final String Function(SongInfo song) resolveSongCover;
  final String Function(SongInfo song) resolvePlatformId;
  final bool Function(SongInfo song) isSongLiked;
  final SongInfoTapCallback onTapSong;
  final SongInfoActionCallback onLikeSong;
  final SongInfoMoreCallback onMoreSong;
  final SongInfoNullableTextBuilder? artistAlbumTextBuilder;
  final SongInfoTextBuilder? subtitleTextBuilder;
  final bool initialLoading;
  final String? errorMessage;
  final Future<void> Function()? onRetry;
  final bool enablePaging;
  final bool loadingMore;
  final bool hasMore;
  final Future<void> Function()? onLoadMore;
  final Widget? empty;
  final String? countText;
  final VoidCallback? onPlayAll;
  final bool batchMode;
  final Set<String> selectedSongKeys;
  final int selectedCount;
  final bool allSelected;
  final VoidCallback? onEnterBatchMode;
  final VoidCallback? onCancelBatch;
  final VoidCallback? onSelectAllLoaded;
  final void Function(SongInfo song)? onToggleSongSelection;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (countText != null)
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: MusicDetailPlayAllHeaderBox(
              countText: countText!,
              enabled: songs.isNotEmpty,
              onPlayAll: onPlayAll ?? () {},
              onBatchAction: songs.isEmpty ? null : onEnterBatchMode,
              batchMode: batchMode,
              selectedCount: selectedCount,
              allSelected: allSelected,
              onSelectAll: songs.isEmpty ? null : onSelectAllLoaded,
              onCancelBatch: batchMode ? onCancelBatch : null,
            ),
          ),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (errorMessage != null && songs.isEmpty && !initialLoading) {
      return _RetryBody(message: errorMessage!, onRetry: onRetry);
    }
    return SongListComponent(
      initialLoading: initialLoading,
      itemCount: songs.length,
      enablePaging: enablePaging,
      loadingMore: loadingMore,
      hasMore: hasMore,
      onLoadMore: onLoadMore,
      empty: empty,
      itemBuilder: (context, index) {
        final song = songs[index];
        final songCover = resolveSongCover(song);
        return OnlineSongListItem(
          song: song,
          artistAlbumText: artistAlbumTextBuilder?.call(song),
          subtitleText: subtitleTextBuilder?.call(song) ?? '',
          coverUrl: songCover.trim().isEmpty ? null : songCover,
          isCurrent: isCurrentSongTrack(currentTrack, song),
          isLiked: isSongLiked(song),
          selectable: batchMode,
          selected: selectedSongKeys.contains(
            buildSongBatchKey(
              songId: song.id,
              platform: resolvePlatformId(song),
            ),
          ),
          showActions: !batchMode,
          onTap: batchMode
              ? null
              : () {
                  final result = onTapSong(song, songCover, index);
                  if (result is Future<void>) {
                    unawaited(result);
                  }
                },
          onSelectTap: onToggleSongSelection == null
              ? null
              : () => onToggleSongSelection!(song),
          onLikeTap: batchMode
              ? null
              : () {
                  final result = onLikeSong(song);
                  if (result is Future<void>) {
                    unawaited(result);
                  }
                },
          onMoreTap: batchMode ? null : () => onMoreSong(song, songCover),
        );
      },
    );
  }
}

class _RetryBody extends ConsumerWidget {
  const _RetryBody({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry == null ? null : () => onRetry!(),
            child: Text(AppI18n.t(config, 'common.retry')),
          ),
        ],
      ),
    );
  }
}
