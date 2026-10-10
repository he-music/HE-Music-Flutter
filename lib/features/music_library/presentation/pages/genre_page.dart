import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../helpers/local_song_playback_helper.dart';
import '../widgets/local_song_list_item.dart';
import '../widgets/local_songs_stream_view.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/song_list_component.dart';
import '../../../../shared/widgets/song_list_item.dart';
import '../../domain/entities/local_song.dart';
import '../providers/local_library_providers.dart';
import '../widgets/artwork_enricher.dart';

/// 本地流派详情页
///
/// 显示指定流派下的所有歌曲。
class GenrePage extends ConsumerWidget {
  const GenrePage({super.key, required this.genreName});

  final String genreName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final repository = ref.watch(localMusicRepositoryProvider);
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text(genreName)),
      body: LocalSongsStreamView(
        sourceKey: (repository, genreName),
        watchSongs: () => repository.watchSongsByGenre(genreName),
        localeCode: config.localeCode,
        emptyText: AppI18n.t(config, 'local.empty.genre'),
        builder: (context, genreSongs) {
          return ArtworkEnricher(
            songs: genreSongs,
            builder: (context, genreSongs) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      AppI18n.formatByLocaleCode(
                        config.localeCode,
                        'local.group.genre_subtitle',
                        {'songs': '${genreSongs.length}'},
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SongListComponent(
                      itemCount: genreSongs.length,
                      enablePaging: false,
                      itemBuilder: (context, index) {
                        final song = genreSongs[index];
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
                              if (song.formatLabel.isNotEmpty) song.formatLabel,
                            ],
                          ),
                          onTap: () => _playSong(ref, genreSongs, index),
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

  Future<void> _playSong(WidgetRef ref, List<LocalSong> songs, int index) =>
      playLocalSongs(ref, songs, startIndex: index);
}
