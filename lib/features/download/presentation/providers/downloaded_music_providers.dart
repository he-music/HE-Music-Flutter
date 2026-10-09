import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../player/domain/entities/player_track.dart';
import '../../domain/entities/downloaded_song.dart';
import 'download_providers.dart';

final downloadedSongsProvider =
    StreamProvider.autoDispose<List<DownloadedSong>>((ref) {
      return ref.watch(downloadedMusicRepositoryProvider).watchSongs();
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

final downloadedArtworkProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, path) async {
      if (path.isEmpty) return null;
      try {
        return await File(path).readAsBytes();
      } on FileSystemException {
        return null;
      }
    });
