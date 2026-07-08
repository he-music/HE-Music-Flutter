import '../../../../shared/models/he_music_models.dart';

class SongDetailContent {
  const SongDetailContent({
    required this.song,
    required this.publishTime,
    required this.language,
  });

  final SongInfo song;
  final String publishTime;
  final String language;
}
