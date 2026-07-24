import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/online_platform.dart';

enum SearchType { comprehensive, song, playlist, album, artist, video, lyric }

extension SearchTypeApi on SearchType {
  String get apiType {
    return switch (this) {
      SearchType.comprehensive => 'comprehensive',
      SearchType.song => 'song',
      SearchType.playlist => 'playlist',
      SearchType.album => 'album',
      SearchType.artist => 'artist',
      SearchType.video => 'mv',
      SearchType.lyric => 'lyric',
    };
  }
}

extension SearchTypePlatformFeature on SearchType {
  BigInt get requiredPlatformFeatureFlag {
    return switch (this) {
      SearchType.comprehensive =>
        PlatformFeatureSupportFlag.comprehensiveSearch,
      SearchType.song => PlatformFeatureSupportFlag.searchSong,
      SearchType.playlist => PlatformFeatureSupportFlag.searchPlaylist,
      SearchType.album => PlatformFeatureSupportFlag.searchAlbum,
      SearchType.artist => PlatformFeatureSupportFlag.searchSinger,
      SearchType.video => PlatformFeatureSupportFlag.searchMv,
      SearchType.lyric => PlatformFeatureSupportFlag.searchLyric,
    };
  }
}

extension SearchTypeI18n on SearchType {
  String get labelKey {
    return switch (this) {
      SearchType.comprehensive => 'search.type.comprehensive',
      SearchType.song => 'search.type.song',
      SearchType.playlist => 'search.type.playlist',
      SearchType.album => 'search.type.album',
      SearchType.artist => 'search.type.artist',
      SearchType.video => 'search.type.video',
      SearchType.lyric => 'search.type.lyric',
    };
  }
}

extension SearchTypeComprehensiveSection on SearchType {
  bool get supportsStandaloneSearch => this != SearchType.comprehensive;
}

class OnlineSearchPageResult<T> {
  const OnlineSearchPageResult({
    required this.platform,
    required this.keyword,
    required this.items,
    required this.pageIndex,
    required this.pageSize,
    required this.totalCount,
    required this.hasMore,
  });

  final String platform;
  final String keyword;
  final List<T> items;
  final int pageIndex;
  final int pageSize;
  final int totalCount;
  final bool hasMore;
}

class OnlineComprehensiveSearchSection<T> {
  const OnlineComprehensiveSearchSection({
    this.items = const [],
    this.hasMore = false,
    this.totalCount = 0,
  });

  final List<T> items;
  final bool hasMore;
  final int totalCount;

  bool get isEmpty => items.isEmpty;
}

/// 最佳匹配推荐项，包含类型和原始数据
class BestMatchRecommendItem {
  const BestMatchRecommendItem({
    required this.resourceType,
    required this.data,
  });

  /// 推荐类型: artist | song | playlist | album | mv
  final String resourceType;
  final Object data;

  /// 将 resourceType 映射为 SearchType，用于复用现有渲染逻辑
  SearchType? get searchType {
    return switch (resourceType) {
      'song' => SearchType.song,
      'artist' => SearchType.artist,
      'playlist' => SearchType.playlist,
      'album' => SearchType.album,
      'mv' => SearchType.video,
      _ => null,
    };
  }
}

class OnlineComprehensiveSearchResult {
  const OnlineComprehensiveSearchResult({
    required this.keyword,
    this.bestMatch = const <BestMatchRecommendItem>[],
    this.song = const OnlineComprehensiveSearchSection<SearchSongInfo>(),
    this.playlist =
        const OnlineComprehensiveSearchSection<Map<String, dynamic>>(),
    this.album = const OnlineComprehensiveSearchSection<Map<String, dynamic>>(),
    this.video = const OnlineComprehensiveSearchSection<Map<String, dynamic>>(),
    this.artist =
        const OnlineComprehensiveSearchSection<Map<String, dynamic>>(),
  });

  final String keyword;
  final List<BestMatchRecommendItem> bestMatch;
  final OnlineComprehensiveSearchSection<SearchSongInfo> song;
  final OnlineComprehensiveSearchSection<Map<String, dynamic>> playlist;
  final OnlineComprehensiveSearchSection<Map<String, dynamic>> album;
  final OnlineComprehensiveSearchSection<Map<String, dynamic>> video;
  final OnlineComprehensiveSearchSection<Map<String, dynamic>> artist;

  bool get hasBestMatch => bestMatch.isNotEmpty;
}

String displayTitle(SearchType type, Map<String, dynamic> item) {
  return switch (type) {
    SearchType.comprehensive => '-',
    SearchType.playlist => searchPlaylistInfo(item).name,
    SearchType.album => searchAlbumInfo(item).name,
    SearchType.artist => searchArtistInfo(item).name,
    SearchType.video => searchVideoInfo(item).name,
    SearchType.song || SearchType.lyric => '-',
  };
}

String displaySubtitle(SearchType type, Map<String, dynamic> item) {
  return switch (type) {
    SearchType.comprehensive => '-',
    SearchType.playlist =>
      searchPlaylistInfo(item).creator.isEmpty
          ? '-'
          : searchPlaylistInfo(item).creator,
    SearchType.album => _artistNames(searchAlbumInfo(item).artists),
    SearchType.artist => _artistSearchSubtitle(searchArtistInfo(item)),
    SearchType.video => _videoSearchSubtitle(searchVideoInfo(item)),
    SearchType.song || SearchType.lyric => '-',
  };
}

String artistSongCount(Map<String, dynamic> item) {
  return _countText(searchArtistInfo(item).songCount);
}

String artistAlbumCount(Map<String, dynamic> item) {
  return _countText(searchArtistInfo(item).albumCount);
}

String artistVideoCount(Map<String, dynamic> item) {
  return _countText(searchArtistInfo(item).mvCount);
}

String artistText(dynamic value) {
  return _safeText(_artistNames(_artistsFromDynamic(value)));
}

PlaylistInfo searchPlaylistInfo(Map<String, dynamic> item) {
  return PlaylistInfo.fromMap(
    item,
    fallbackPlatform: _safePlatform(item['platform']),
  );
}

AlbumInfo searchAlbumInfo(Map<String, dynamic> item) {
  return AlbumInfo.fromMap(
    item,
    fallbackPlatform: _safePlatform(item['platform']),
  );
}

ArtistInfo searchArtistInfo(Map<String, dynamic> item) {
  return ArtistInfo.fromMap(
    item,
    fallbackPlatform: _safePlatform(item['platform']),
  );
}

MvInfo searchVideoInfo(Map<String, dynamic> item) {
  return MvInfo.fromMap(
    item,
    fallbackPlatform: _safePlatform(item['platform']),
  );
}

String _artistSearchSubtitle(ArtistInfo artist) {
  final platform = _safeText(artist.platform);
  final alias = artist.alias.trim();
  if (alias.isEmpty) {
    return platform;
  }
  return '$platform · $alias';
}

String _videoSearchSubtitle(MvInfo video) {
  final creator = video.creator.trim();
  if (creator.isNotEmpty) {
    return creator;
  }
  return _safeText(video.platform);
}

String text(dynamic value) {
  if (value == null) {
    return '-';
  }
  final parsed = '$value'.trim();
  if (parsed.isEmpty) {
    return '-';
  }
  return parsed;
}

String _countText(dynamic value) {
  final parsed = int.tryParse('${value ?? ''}');
  if (parsed == null || parsed < 0) {
    return '0';
  }
  return '$parsed';
}

String _safeText(String? value) {
  final parsed = (value ?? '').trim();
  if (parsed.isEmpty) {
    return '-';
  }
  return parsed;
}

String _string(dynamic value) => '${value ?? ''}'.trim();

String _safePlatform(dynamic value) {
  final platform = _string(value);
  if (platform.isEmpty) {
    return '-';
  }
  return platform;
}

List<SongInfoArtistInfo> _artistsFromDynamic(dynamic value) {
  if (value is List) {
    return value
        .map((entry) {
          if (entry is Map<String, dynamic>) {
            return SongInfoArtistInfo.fromMap(entry);
          }
          if (entry is Map) {
            return SongInfoArtistInfo.fromMap(
              entry.map((key, item) => MapEntry('$key', item)),
            );
          }
          return SongInfoArtistInfo(id: '', name: '$entry'.trim());
        })
        .where((entry) => entry.name.isNotEmpty)
        .toList(growable: false);
  }
  final text = _string(value);
  if (text.isEmpty) {
    return const <SongInfoArtistInfo>[];
  }
  return <SongInfoArtistInfo>[SongInfoArtistInfo(id: '', name: text)];
}

String _artistNames(List<SongInfoArtistInfo> artists) {
  final names = artists
      .map((entry) => entry.name.trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
  if (names.isEmpty) {
    return '';
  }
  return names.join('/');
}
