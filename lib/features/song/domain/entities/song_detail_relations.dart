import '../../../../shared/models/he_music_models.dart';

class SongDetailRelations {
  const SongDetailRelations({
    this.similarSongs = const <SongInfo>[],
    this.otherVersionSongs = const <SongInfo>[],
    this.relatedPlaylists = const <PlaylistInfo>[],
    this.relatedMvs = const <MvInfo>[],
  });

  final List<SongInfo> similarSongs;
  final List<SongInfo> otherVersionSongs;
  final List<PlaylistInfo> relatedPlaylists;
  final List<MvInfo> relatedMvs;

  bool get isEmpty =>
      similarSongs.isEmpty &&
      otherVersionSongs.isEmpty &&
      relatedPlaylists.isEmpty &&
      relatedMvs.isEmpty;
}
