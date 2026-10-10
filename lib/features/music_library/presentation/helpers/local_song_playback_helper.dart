import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/local_song.dart';
import '../providers/local_library_providers.dart';

PlayerTrack localSongToTrack(LocalSong song, {String? artworkUrl}) =>
    PlayerTrack(
      id: 'local-${song.id}',
      title: song.title,
      path: song.filePath,
      artist: song.artist,
      album: song.album,
      artworkUrl: artworkUrl,
      artworkBytes: song.artworkBytes,
      format: song.formatLabel.isEmpty ? null : song.formatLabel,
      bitrate: song.bitrate,
      sampleRate: song.sampleRate,
      platform: 'local',
    );

/// Single-song actions preserve the queue; batch actions play the full selection.
Future<void> playLocalSongs(
  WidgetRef ref,
  List<LocalSong> songs, {
  int startIndex = 0,
  bool replaceQueue = false,
}) async {
  if (startIndex < 0 || startIndex >= songs.length) return;
  final localeCode = ref.read(appConfigProvider).localeCode;
  final player = ref.read(playerControllerProvider.notifier);
  final repository = ref.read(localMusicRepositoryProvider);
  final extractor = ref.read(localArtworkExtractorProvider);
  try {
    final song = songs[startIndex];
    final artwork = await extractor.getArtworkFile(song.filePath);
    if (!ref.context.mounted) return;
    final track = localSongToTrack(song, artworkUrl: artwork?.path);
    if (replaceQueue) {
      final tracks = songs.map(localSongToTrack).toList(growable: false);
      tracks[startIndex] = track;
      await player.replaceQueue(tracks, startIndex: startIndex);
    } else {
      await player.insertNextAndPlay(track);
    }
    await repository.incrementPlayCount(song.id);
  } catch (_) {
    AppMessageService.showError(
      AppI18n.tByLocaleCode(localeCode, 'local.play_failed'),
    );
  }
}
