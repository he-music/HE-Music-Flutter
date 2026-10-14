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

/// 本地歌手详情页
///
/// 显示指定歌手的所有歌曲，按专辑分组。
class LocalArtistDetailPage extends ConsumerWidget {
  const LocalArtistDetailPage({super.key, required this.artistName});

  final String artistName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appConfigProvider.select((config) => config.localeCode));
    final config = ref.read(appConfigProvider);
    final repository = ref.watch(localMusicRepositoryProvider);
    return DetailPageShell(
      child: Scaffold(
        appBar: AppBar(leading: const AppBackButton(), title: Text(artistName)),
        body: LocalSongsStreamView(
          sourceKey: (repository, artistName),
          watchSongs: () => repository.watchSongsByArtist(artistName),
          localeCode: config.localeCode,
          emptyText: AppI18n.t(config, 'local.empty.artist'),
          builder: (context, songs) {
            return ArtworkEnricher(
              songs: songs,
              builder: (context, songs) {
                final albumCount = songs
                    .map((s) => s.album)
                    .where((a) => a.isNotEmpty)
                    .toSet()
                    .length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 顶部统计区
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            artistName,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppI18n.formatByLocaleCode(
                              config.localeCode,
                              'local.group.artist_subtitle',
                              {
                                'songs': '${songs.length}',
                                'albums': '$albumCount',
                              },
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
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
                      trailing: TextButton.icon(
                        onPressed: () => _shufflePlay(ref, songs),
                        icon: const Icon(Icons.shuffle_rounded),
                        label: Text(AppI18n.t(config, 'local.shuffle')),
                      ),
                    ),
                    // 歌曲列表
                    Expanded(
                      child: SongListComponent(
                        itemCount: songs.length,
                        enablePaging: false,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return LocalSongListItem(
                            song: song,
                            data: SongListItemData(
                              title: song.title,
                              artistAlbumText: '${song.artist} - ${song.album}',
                              subtitleText: song.filePath,
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

  Future<void> _playSong(WidgetRef ref, List<LocalSong> songs, int index) =>
      playLocalSongs(ref, songs, startIndex: index);

  Future<void> _playAll(WidgetRef ref, List<LocalSong> songs) =>
      playLocalSongs(ref, songs, replaceQueue: true);

  Future<void> _shufflePlay(WidgetRef ref, List<LocalSong> songs) =>
      playLocalSongs(
        ref,
        List<LocalSong>.from(songs)..shuffle(),
        replaceQueue: true,
      );
}
