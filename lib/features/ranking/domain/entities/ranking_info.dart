import 'ranking_preview_song.dart';

class RankingInfo {
  const RankingInfo({
    required this.id,
    required this.platform,
    required this.name,
    required this.coverUrl,
    required this.previewSongs,
  });

  final String id;
  final String platform;
  final String name;
  final String coverUrl;
  final List<RankingPreviewSong> previewSongs;
}
