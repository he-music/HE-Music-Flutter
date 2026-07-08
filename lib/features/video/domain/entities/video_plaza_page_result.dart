import '../../../../shared/models/he_music_models.dart';

class VideoPlazaPageResult {
  const VideoPlazaPageResult({required this.list, required this.hasMore});

  final List<MvInfo> list;
  final bool hasMore;
}
