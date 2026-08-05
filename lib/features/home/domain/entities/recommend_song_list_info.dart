import '../../../../shared/models/he_music_models.dart';

class RecommendSongListInfo {
  const RecommendSongListInfo({
    required this.id,
    required this.title,
    required this.cover,
    required this.description,
    required this.songs,
  });

  final String id;
  final String title;
  final String cover;
  final String description;
  final List<SongInfo> songs;
}
