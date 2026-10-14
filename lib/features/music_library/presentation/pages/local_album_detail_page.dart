import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../helpers/local_song_playback_helper.dart';
import '../widgets/local_song_list_item.dart';
import '../widgets/local_songs_stream_view.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/song_list_component.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/music_detail_slivers.dart';
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
    ref.watch(appConfigProvider.select((config) => config.localeCode));
    final config = ref.read(appConfigProvider);
    final repository = ref.watch(localMusicRepositoryProvider);
    return DetailPageShell(
      child: Scaffold(
        appBar: AppBar(leading: const AppBackButton(), title: Text(albumName)),
        body: LocalSongsStreamView(
          sourceKey: (repository, albumName),
          watchSongs: () => repository.watchSongsByAlbum(albumName),
          localeCode: config.localeCode,
          emptyText: AppI18n.t(config, 'local.empty.album'),
          builder: (context, songs) {
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
                    .firstWhere(
                      (s) => s.year != null,
                      orElse: () => songs.first,
                    )
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
                    MusicDetailPlayAllHeaderBox(
                      countText: AppI18n.format(
                        config,
                        'detail.play_all_count',
                        {'count': '${songs.length}'},
                      ),
                      onPlayAll: () => _playAll(ref, songs),
                    ),
                    // 曲目列表
                    Expanded(
                      child: SongListComponent(
                        itemCount: songs.length,
                        enablePaging: false,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          final trackNum = song.trackNumber;
                          return LocalSongListItem(
                            song: song,
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
                                if (song.formatLabel.isNotEmpty)
                                  song.formatLabel,
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

  Future<void> _playSong(WidgetRef ref, List<LocalSong> songs, int index) =>
      playLocalSongs(ref, songs, startIndex: index);

  Future<void> _playAll(WidgetRef ref, List<LocalSong> songs) =>
      playLocalSongs(ref, songs, replaceQueue: true);
}
