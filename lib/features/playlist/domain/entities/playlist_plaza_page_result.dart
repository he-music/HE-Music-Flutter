import '../../../../shared/models/he_music_models.dart';

class PlaylistPlazaPageResult {
  const PlaylistPlazaPageResult({
    required this.list,
    required this.hasMore,
    required this.lastId,
  });

  final List<PlaylistInfo> list;
  final bool hasMore;
  final String lastId;
}
