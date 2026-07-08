import '../../../../shared/models/he_music_models.dart';
import 'album_detail_song.dart';

class AlbumDetailContent {
  const AlbumDetailContent({required this.info, required this.songs});

  final AlbumInfo info;
  final List<AlbumDetailSong> songs;

  String get id => info.id;
  String get platform => info.platform;
  String get title => info.name;
  String get subtitle => info.artists
      .map((item) => item.name.trim())
      .where((item) => item.isNotEmpty)
      .join(' / ');
  String get coverUrl => info.cover;
  String get description => info.description;
  String get publishTime => info.publishTime;
}
