import 'he_music_models.dart';

class SongListPage {
  const SongListPage({required this.songs, required this.hasMore, this.lastId});

  final List<SongInfo> songs;
  final bool hasMore;
  final String? lastId;
}
