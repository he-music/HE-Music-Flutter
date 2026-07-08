import '../../../../shared/models/he_music_models.dart';

class ArtistPlazaPageResult {
  const ArtistPlazaPageResult({required this.list, required this.hasMore});

  final List<ArtistInfo> list;
  final bool hasMore;
}
