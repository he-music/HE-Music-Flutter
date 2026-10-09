import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/skin/app_skin_bottom_sheet.dart';
import '../../../../shared/widgets/music_detail_slivers.dart';
import '../../../../shared/widgets/song_list_item.dart';
import '../../../player/domain/entities/player_queue_source.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/downloaded_song.dart';
import '../providers/download_providers.dart';
import '../providers/downloaded_music_providers.dart';

class DownloadedMusicContent extends ConsumerStatefulWidget {
  const DownloadedMusicContent({
    required this.locale,
    required this.onOpenTasks,
    super.key,
  });

  final String locale;
  final VoidCallback onOpenTasks;

  @override
  ConsumerState<DownloadedMusicContent> createState() =>
      _DownloadedMusicContentState();
}

class _DownloadedMusicContentState extends ConsumerState<DownloadedMusicContent>
    with WidgetsBindingObserver {
  final Set<String> _busySongs = {};
  String text(String key) => AppI18n.tByLocaleCode(widget.locale, key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(downloadedSongsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(downloadedSongsProvider);
    return songs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(downloadedSongsProvider),
          child: Text(text('common.retry')),
        ),
      ),
      data: (allSongs) {
        final playable = allSongs
            .where((song) => song.isAvailable)
            .toList(growable: false);
        if (allSongs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                text('download.library.empty'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return Column(
          children: [
            MusicDetailPlayAllHeaderBox(
              key: const Key('downloaded-music-play-all'),
              countText: AppI18n.formatByLocaleCode(
                widget.locale,
                'detail.play_all_count',
                {'count': '${playable.length}'},
              ),
              enabled: playable.isNotEmpty,
              onPlayAll: () => unawaited(_play(playable, 0)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: allSongs.length,
                itemBuilder: (context, index) {
                  final song = allSongs[index];
                  final task = song.task;
                  return Consumer(
                    builder: (context, ref, child) {
                      final cover = ref
                          .watch(
                            downloadedArtworkProvider(task.artworkPath ?? ''),
                          )
                          .value;
                      return SongListItem(
                        key: ValueKey('downloaded-song-${song.id}'),
                        data: SongListItemData(
                          title: task.title,
                          artistAlbumText: [task.artist, task.album]
                              .whereType<String>()
                              .where((value) => value.isNotEmpty)
                              .join(' · '),
                          subtitleText: song.isAvailable
                              ? '${task.effectiveFileExtension.toUpperCase()} · ${task.quality.label}'
                              : text('download.library.missing'),
                          coverBytes: cover,
                        ),
                        onTap: song.isAvailable
                            ? () => unawaited(
                                _play(playable, playable.indexOf(song)),
                              )
                            : null,
                        onMoreTap: () => unawaited(_showActions(song)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _play(List<DownloadedSong> songs, int index) async {
    await _run(() async {
      await ref
          .read(playerControllerProvider.notifier)
          .replaceQueue(
            songs.map(downloadedSongToTrack).toList(growable: false),
            startIndex: index,
            queueSource: PlayerQueueSource(
              routePath: AppRoutes.downloads,
              queryParameters: const {'tab': 'downloaded'},
              title: text('download.library.title'),
            ),
          );
      if (ref.read(playerControllerProvider).playbackFailure != null) {
        ref.invalidate(downloadedSongsProvider);
      }
    });
  }

  Future<void> _showActions(DownloadedSong song) async {
    final action = await showAppThemedBottomSheet<String>(
      context: context,
      fitContent: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          if (song.isAvailable)
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(text('download.library.add_to_queue')),
              onTap: () => Navigator.of(sheetContext).pop('queue'),
            ),
          ListTile(
            enabled: !_busySongs.contains(song.id),
            leading: const Icon(Icons.download_rounded),
            title: Text(text('download.library.redownload')),
            onTap: () => Navigator.of(sheetContext).pop('redownload'),
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline_rounded),
            title: Text(text('download.library.remove')),
            onTap: () => Navigator.of(sheetContext).pop('remove'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    await _run(() async {
      switch (action) {
        case 'queue':
          await ref
              .read(playerControllerProvider.notifier)
              .appendTrack(downloadedSongToTrack(song));
          if (mounted) {
            AppMessageService.showSuccess(
              text('download.library.added_to_queue'),
            );
          }
        case 'redownload':
          if (!_busySongs.add(song.id)) return;
          try {
            await ref
                .read(downloadControllerProvider.notifier)
                .redownloadSavedSong(song.task);
            if (mounted) widget.onOpenTasks();
          } finally {
            _busySongs.remove(song.id);
          }
        case 'remove':
          await ref.read(downloadedMusicRepositoryProvider).remove(song.id);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) AppMessageService.showError(text('download.library.failed'));
    }
  }
}
