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
      body: StreamBuilder<List<LocalSong>>(
        stream: repository.watchSongs(searchQuery: genreName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final songs = snapshot.data ?? [];
          if (songs.isEmpty) {
            return Center(
              child: Text(
                AppI18n.t(config, 'local.empty.genre'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          final genreSongs = songs.where((s) => s.genre == genreName).toList();
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
                        return SongListItem(
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
}
