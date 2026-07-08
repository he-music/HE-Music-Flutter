import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../features/player/domain/entities/player_track.dart';
import '../../../../features/player/presentation/providers/player_providers.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/song_list_component.dart';
import '../../../../shared/widgets/song_list_item.dart';
import '../../domain/entities/local_song.dart';
import '../providers/local_library_providers.dart';
import '../widgets/artwork_enricher.dart';

/// 本地专辑详情页
///
/// 显示指定专辑的所有歌曲，按曲目编号排序。
class LocalAlbumDetailPage extends ConsumerWidget {
  const LocalAlbumDetailPage({super.key, required this.albumName});

  final String albumName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final repository = ref.watch(localMusicRepositoryProvider);
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text(albumName)),
      body: StreamBuilder<List<LocalSong>>(
        stream: repository.watchSongsByAlbum(albumName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final songs = snapshot.data ?? [];
          if (songs.isEmpty) {
            return Center(
              child: Text(
                AppI18n.t(config, 'local.empty.album'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          return ArtworkEnricher(
            songs: songs,
            builder: (context, songs) {
              final artistNames = songs
                  .map((s) => s.artist)
                  .where((a) => a.isNotEmpty)
                  .toSet();
              final totalDuration = songs.fold<int>(
                0,
                (sum, s) => sum + s.duration.inMilliseconds,
              );
              final durationText = _formatDuration(totalDuration);
              final year = songs
                  .firstWhere((s) => s.year != null, orElse: () => songs.first)
                  .year;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 顶部专辑信息
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          albumName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          artistNames.join(' / '),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (year != null) '$year',
                            '${songs.length} 首',
                            durationText,
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // 播放全部按钮
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _playAll(ref, songs),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(AppI18n.t(config, 'local.play_all')),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 曲目列表
                  Expanded(
                    child: SongListComponent(
                      itemCount: songs.length,
                      enablePaging: false,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        final trackNum = song.trackNumber;
                        return SongListItem(
                          data: SongListItemData(
                            title: song.title,
                            artistAlbumText: '${song.artist} - ${song.album}',
                            subtitleText: trackNum != null
                                ? '$trackNum. ${song.title}'
                                : song.filePath,
                            coverBytes: song.artworkBytes,
                            tags: <String>[
                              AppI18n.tByLocaleCode(
                                config.localeCode,
                                'local.tag.local',
                              ),
                              if (song.formatLabel.isNotEmpty) song.formatLabel,
                            ],
                          ),
                          onTap: () => _playSong(ref, songs, index),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours 小时 $minutes 分钟';
    }
    return '$minutes 分钟';
  }

  Future<void> _playSong(
    WidgetRef ref,
    List<LocalSong> songs,
    int index,
  ) async {
    if (index < 0 || index >= songs.length) return;
    final song = songs[index];
    final extractor = ref.read(localArtworkExtractorProvider);
    final artworkFile = await extractor.getArtworkFile(song.filePath);
    final track = PlayerTrack(
      id: 'local-${song.id}',
      title: song.title,
      path: song.filePath,
      artist: song.artist,
      album: song.album,
      url: '',
      artworkUrl: artworkFile?.path,
      artworkBytes: song.artworkBytes,
      platform: 'local',
    );
    await ref.read(playerControllerProvider.notifier).insertNextAndPlay(track);
    ref.read(localMusicRepositoryProvider).incrementPlayCount(song.id);
  }

  Future<void> _playAll(WidgetRef ref, List<LocalSong> songs) async {
    if (songs.isEmpty) return;
    await _playSong(ref, songs, 0);
  }
}
