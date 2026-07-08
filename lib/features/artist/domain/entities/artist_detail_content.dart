import '../../../../shared/models/he_music_models.dart';
import 'artist_detail_song.dart';

class ArtistDetailContent {
  const ArtistDetailContent({required this.info, required this.songs});

  final ArtistInfo info;
  final List<ArtistDetailSong> songs;

  String get id => info.id;
  String get platform => info.platform;
  String get title => info.name;
  String get subtitle => info.alias;
  String get coverUrl => info.cover;
  String get description => info.description;
  String get songCount => info.songCount;
  String get albumCount => info.albumCount;
  String get videoCount => info.mvCount;
}
