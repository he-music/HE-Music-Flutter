import '../../../../shared/models/he_music_models.dart';
import 'home_discover_item.dart';

class HomeDiscoverSection {
  const HomeDiscoverSection({
    required this.key,
    required this.titleKey,
    required this.type,
    this.songs = const <SongInfo>[],
    this.albums = const <AlbumInfo>[],
    this.playlists = const <PlaylistInfo>[],
    this.videos = const <MvInfo>[],
  });

  final String key;
  final String titleKey;
  final HomeDiscoverItemType type;
  final List<SongInfo> songs;
  final List<AlbumInfo> albums;
  final List<PlaylistInfo> playlists;
  final List<MvInfo> videos;

  bool get isEmpty {
    return switch (type) {
      HomeDiscoverItemType.song => songs.isEmpty,
      HomeDiscoverItemType.album => albums.isEmpty,
      HomeDiscoverItemType.playlist => playlists.isEmpty,
      HomeDiscoverItemType.video => videos.isEmpty,
    };
  }
}
