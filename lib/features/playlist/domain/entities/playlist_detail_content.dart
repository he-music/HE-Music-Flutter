import '../../../../shared/models/he_music_models.dart';
import 'playlist_detail_song.dart';

class PlaylistDetailContent {
  const PlaylistDetailContent({required this.info, required this.songs});

  final PlaylistInfo info;
  final List<PlaylistDetailSong> songs;

  String get id => info.id;
  String get platform => info.platform;
  String get title => info.name;
  String get subtitle => info.creator;
  String get coverUrl => info.cover;
  String get description => info.description;
  String get playCount => info.playCount;
  String get songCount => info.songCount;
  bool get isDefault => info.isDefault;
}
