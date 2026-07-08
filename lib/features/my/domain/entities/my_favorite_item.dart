import '../../../../shared/models/he_music_models.dart';
import 'my_favorite_type.dart';

class MyFavoriteItem {
  const MyFavoriteItem({
    required this.id,
    required this.platform,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    this.songCount = '',
    this.isDefault = false,
  });

  final String id;
  final String platform;
  final MyFavoriteType type;
  final String title;
  final String subtitle;
  final String coverUrl;
  final String songCount;
  final bool isDefault;

  factory MyFavoriteItem.fromSongInfo({
    required SongInfo song,
    required MyFavoriteType type,
  }) {
    return MyFavoriteItem(
      id: song.id,
      platform: song.platform,
      type: type,
      title: song.name.isEmpty ? 'ID: ${song.id}' : song.name,
      subtitle: song.artist,
      coverUrl: song.cover,
    );
  }

  factory MyFavoriteItem.fromPlaylistInfo({
    required PlaylistInfo playlist,
    required MyFavoriteType type,
  }) {
    final subtitle = playlist.creator.trim();
    return MyFavoriteItem(
      id: playlist.id,
      platform: playlist.platform,
      type: type,
      title: playlist.name.isEmpty ? 'ID: ${playlist.id}' : playlist.name,
      subtitle: subtitle,
      coverUrl: playlist.cover,
      songCount: playlist.songCount,
      isDefault: playlist.isDefault,
    );
  }

  factory MyFavoriteItem.fromAlbumInfo({
    required AlbumInfo album,
    required MyFavoriteType type,
  }) {
    final artistNames = album.artists
        .map((item) => item.name.trim())
        .where((item) => item.isNotEmpty)
        .join('/');
    final subtitle = artistNames.isEmpty
        ? album.platform
        : '${album.platform} · $artistNames';
    return MyFavoriteItem(
      id: album.id,
      platform: album.platform,
      type: type,
      title: album.name.isEmpty ? 'ID: ${album.id}' : album.name,
      subtitle: subtitle,
      coverUrl: album.cover,
    );
  }

  factory MyFavoriteItem.fromArtistInfo({
    required ArtistInfo artist,
    required MyFavoriteType type,
  }) {
    final subtitle = artist.alias.trim().isEmpty
        ? artist.platform
        : '${artist.platform} · ${artist.alias}';
    return MyFavoriteItem(
      id: artist.id,
      platform: artist.platform,
      type: type,
      title: artist.name.isEmpty ? 'ID: ${artist.id}' : artist.name,
      subtitle: subtitle,
      coverUrl: artist.cover,
    );
  }
}
