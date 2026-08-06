import '../../features/player/domain/entities/player_track.dart';
import '../models/he_music_models.dart';

typedef CurrentTrackIdentity = ({String id, String platform});

/// 播放高亮只依赖歌曲身份，避免时长等媒体元数据变化触发列表重建。
CurrentTrackIdentity? currentTrackIdentityOf(PlayerTrack? track) {
  if (track == null) {
    return null;
  }
  return (id: track.id.trim(), platform: (track.platform ?? '').trim());
}

bool isCurrentSongTrack(PlayerTrack? track, SongInfo song) {
  return isCurrentSongIdentity(currentTrackIdentityOf(track), song);
}

bool isCurrentSongIdentity(CurrentTrackIdentity? identity, SongInfo song) {
  if (identity == null) {
    return false;
  }
  final trackId = identity.id;
  final songId = song.id.trim();
  if (trackId.isEmpty || songId.isEmpty || trackId != songId) {
    return false;
  }
  final trackPlatform = identity.platform;
  final songPlatform = song.platform.trim();
  if (trackPlatform.isEmpty || songPlatform.isEmpty) {
    return true;
  }
  return trackPlatform == songPlatform;
}
