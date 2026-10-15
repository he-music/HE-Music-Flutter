import '../../../../shared/models/he_music_models.dart';

class SongDetailSection {
  const SongDetailSection({
    required this.resourceType,
    required this.title,
    this.songs = const <SongInfo>[],
    this.albums = const <AlbumInfo>[],
    this.mvs = const <MvInfo>[],
    this.playlists = const <PlaylistInfo>[],
  });

  final String resourceType;
  final String title;
  final List<SongInfo> songs;
  final List<AlbumInfo> albums;
  final List<MvInfo> mvs;
  final List<PlaylistInfo> playlists;

  bool get isEmpty => switch (resourceType) {
    'song' => songs.isEmpty,
    'album' => albums.isEmpty,
    'mv' => mvs.isEmpty,
    'playlist' => playlists.isEmpty,
    _ => true,
  };

  factory SongDetailSection.fromMap(
    Map<String, dynamic> raw, {
    required String fallbackPlatform,
  }) => SongDetailSection(
    resourceType: raw['resource_type'] as String? ?? '',
    title: raw['title'] as String? ?? '',
    songs: _parseResources(
      raw['songs'],
      (item) => SongInfo.fromMap(item, fallbackPlatform: fallbackPlatform),
    ),
    albums: _parseResources(
      raw['albums'],
      (item) => AlbumInfo.fromMap(item, fallbackPlatform: fallbackPlatform),
    ),
    mvs: _parseResources(
      raw['mvs'],
      (item) => MvInfo.fromMap(item, fallbackPlatform: fallbackPlatform),
    ),
    playlists: _parseResources(
      raw['playlists'],
      (item) => PlaylistInfo.fromMap(item, fallbackPlatform: fallbackPlatform),
    ),
  );

  static List<T> _parseResources<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (raw is! List) return <T>[];
    return List<T>.unmodifiable(
      raw.whereType<Map>().map(
        (item) => parse(Map<String, dynamic>.from(item)),
      ),
    );
  }
}
