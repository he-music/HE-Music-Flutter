import '../../../../shared/image/local_artwork_bytes_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/song_sort_providers.dart';
import '../../../../shared/utils/song_sort.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../domain/entities/downloaded_song.dart';
import 'download_providers.dart';

final downloadedSongsProvider =
    StreamProvider.autoDispose<List<DownloadedSong>>((ref) {
      return ref.watch(downloadedMusicRepositoryProvider).watchSongs();
    });

final sortedDownloadedSongsProvider =
    Provider.autoDispose<AsyncValue<List<DownloadedSong>>>((ref) {
      final preference = ref.watch(songSortPreferenceProvider);
      return ref
          .watch(downloadedSongsProvider)
          .whenData(
            (songs) => sortSongItems(
              songs,
              preference,
              valuesOf: (song) => SongSortValues(
                title: song.task.title,
                artist: song.task.artist ?? '',
                album: song.task.album ?? '',
                duration: null,
                size: song.task.totalBytes,
              ),
            ),
          );
    });
PlayerTrack downloadedSongToTrack(DownloadedSong song) {
  final task = song.task;
  return PlayerTrack(
    id: song.hasOnlineIdentity ? task.songId! : task.id,
    title: task.title,
    artist: task.artist,
    album: task.album,
    platform: song.hasOnlineIdentity ? task.platform : 'local',
    path: song.filePath,
    artworkUrl: task.artworkPath,
    format: task.effectiveFileExtension,
    bitrate: task.quality.bitrate.round(),
  );
}

final downloadedArtworkProvider = localArtworkBytesProvider;
