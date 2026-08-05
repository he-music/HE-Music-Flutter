import '../../../../shared/models/he_music_models.dart';
import '../../../ranking/domain/entities/ranking_info.dart';

enum HomeSectionType {
  unspecified,
  generic,
  newSongs,
  newAlbums,
  ranking,
  feed,
  unknown,
}

enum HomeResourceType { song, album, playlist, mv, artist, ranking, radio }

class HomePageSection {
  const HomePageSection({
    required this.sectionTypeCode,
    required this.sectionType,
    required this.resourceType,
    required this.title,
    this.songs = const <SongInfo>[],
    this.albums = const <AlbumInfo>[],
    this.playlists = const <PlaylistInfo>[],
    this.mvs = const <MvInfo>[],
    this.artists = const <ArtistInfo>[],
    this.rankings = const <RankingInfo>[],
    this.radios = const <RadioInfo>[],
  });

  final int sectionTypeCode;
  final HomeSectionType sectionType;
  final HomeResourceType resourceType;
  final String title;
  final List<SongInfo> songs;
  final List<AlbumInfo> albums;
  final List<PlaylistInfo> playlists;
  final List<MvInfo> mvs;
  final List<ArtistInfo> artists;
  final List<RankingInfo> rankings;
  final List<RadioInfo> radios;

  bool get isEmpty {
    return switch (resourceType) {
      HomeResourceType.song => songs.isEmpty,
      HomeResourceType.album => albums.isEmpty,
      HomeResourceType.playlist => playlists.isEmpty,
      HomeResourceType.mv => mvs.isEmpty,
      HomeResourceType.artist => artists.isEmpty,
      HomeResourceType.ranking => rankings.isEmpty,
      HomeResourceType.radio => radios.isEmpty,
    };
  }

  HomePageSection appendResources(HomePageSection other) {
    assert(resourceType == other.resourceType);
    return HomePageSection(
      sectionTypeCode: sectionTypeCode,
      sectionType: sectionType,
      resourceType: resourceType,
      title: title,
      songs: resourceType == HomeResourceType.song
          ? <SongInfo>[...songs, ...other.songs]
          : songs,
      albums: resourceType == HomeResourceType.album
          ? <AlbumInfo>[...albums, ...other.albums]
          : albums,
      playlists: resourceType == HomeResourceType.playlist
          ? <PlaylistInfo>[...playlists, ...other.playlists]
          : playlists,
      mvs: resourceType == HomeResourceType.mv
          ? <MvInfo>[...mvs, ...other.mvs]
          : mvs,
      artists: resourceType == HomeResourceType.artist
          ? <ArtistInfo>[...artists, ...other.artists]
          : artists,
      rankings: resourceType == HomeResourceType.ranking
          ? <RankingInfo>[...rankings, ...other.rankings]
          : rankings,
      radios: resourceType == HomeResourceType.radio
          ? <RadioInfo>[...radios, ...other.radios]
          : radios,
    );
  }
}

HomeSectionType parseHomeSectionType(int value) {
  return switch (value) {
    0 => HomeSectionType.unspecified,
    1 => HomeSectionType.generic,
    2 => HomeSectionType.newSongs,
    3 => HomeSectionType.newAlbums,
    4 => HomeSectionType.ranking,
    5 => HomeSectionType.feed,
    _ => HomeSectionType.unknown,
  };
}

HomeResourceType? parseHomeResourceType(String value) {
  return switch (value.trim().toLowerCase()) {
    'song' => HomeResourceType.song,
    'album' => HomeResourceType.album,
    'playlist' => HomeResourceType.playlist,
    'mv' => HomeResourceType.mv,
    'artist' => HomeResourceType.artist,
    'ranking' => HomeResourceType.ranking,
    'radio' => HomeResourceType.radio,
    _ => null,
  };
}

List<HomePageSection> appendRecommendSections(
  List<HomePageSection> current,
  List<HomePageSection> incoming,
) {
  if (current.isEmpty) {
    return List<HomePageSection>.unmodifiable(incoming);
  }
  if (incoming.isEmpty) {
    return List<HomePageSection>.unmodifiable(current);
  }
  final previousLast = current.last;
  final incomingFirst = incoming.first;
  if (previousLast.sectionType != HomeSectionType.feed ||
      incomingFirst.sectionType != HomeSectionType.feed ||
      previousLast.resourceType != incomingFirst.resourceType) {
    return List<HomePageSection>.unmodifiable(<HomePageSection>[
      ...current,
      ...incoming,
    ]);
  }
  return List<HomePageSection>.unmodifiable(<HomePageSection>[
    ...current.take(current.length - 1),
    previousLast.appendResources(incomingFirst),
    ...incoming.skip(1),
  ]);
}
