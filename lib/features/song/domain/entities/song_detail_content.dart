import '../../../../shared/models/he_music_models.dart';
import 'song_detail_field.dart';
import 'song_detail_section.dart';

class SongDetailContent {
  const SongDetailContent({
    required this.song,
    this.fields = const <SongDetailField>[],
    this.sections = const <SongDetailSection>[],
  });

  final SongInfo song;
  final List<SongDetailField> fields;
  final List<SongDetailSection> sections;
}
