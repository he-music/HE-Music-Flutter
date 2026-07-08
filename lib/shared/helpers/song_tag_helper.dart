import '../models/he_music_models.dart';

List<String> songTags(SongInfo song) {
  final tags = <String>[];
  if (song.originalType == 1) {
    tags.add('原唱');
  }
  return tags;
}
