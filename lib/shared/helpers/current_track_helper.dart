import '../../features/player/domain/entities/player_track.dart';
import '../models/he_music_models.dart';

bool isCurrentSongTrack(PlayerTrack? track, SongInfo song) {
  if (track == null) {
    return false;
  }
  final trackId = track.id.trim();
  final songId = song.id.trim();
  if (trackId.isEmpty || songId.isEmpty || trackId != songId) {
    return false;
  }
  final trackPlatform = (track.platform ?? '').trim();
  final songPlatform = song.platform.trim();
  if (trackPlatform.isEmpty || songPlatform.isEmpty) {
    return true;
  }
  return trackPlatform == songPlatform;
}
