class PlatformFeatureSupportFlag {
  static final BigInt comprehensiveSearch = BigInt.one << 0;
  static final BigInt searchSong = BigInt.one << 1;
  static final BigInt searchAlbum = BigInt.one << 2;
  static final BigInt searchPlaylist = BigInt.one << 3;
  static final BigInt searchMv = BigInt.one << 4;
  static final BigInt searchSinger = BigInt.one << 5;
  static final BigInt getSearchSuggest = BigInt.one << 6;
  static final BigInt getSearchHotkey = BigInt.one << 7;
  static final BigInt getTopList = BigInt.one << 8;
  static final BigInt getTopInfo = BigInt.one << 9;
  static final BigInt getTagList = BigInt.one << 10;
  static final BigInt getTagPlaylist = BigInt.one << 11;
  static final BigInt getSingerSong = BigInt.one << 12;
  static final BigInt getSingerAlbum = BigInt.one << 13;
  static final BigInt getSingerMv = BigInt.one << 14;
  static final BigInt getSingerInfo = BigInt.one << 15;
  static final BigInt getSongInfo = BigInt.one << 16;
  static final BigInt getMvInfo = BigInt.one << 17;
  static final BigInt getPlaylistInfo = BigInt.one << 18;
  static final BigInt getAlbumInfo = BigInt.one << 19;
  static final BigInt getSongLyric = BigInt.one << 20;
  static final BigInt getLyricInfo = BigInt.one << 21;
  static final BigInt getSongUrl = BigInt.one << 22;
  static final BigInt getMvUrl = BigInt.one << 23;
  static final BigInt getSongCover = BigInt.one << 24;
  static final BigInt getCommentList = BigInt.one << 25;
  static final BigInt getDailyRecommendSongList = BigInt.one << 26;
  static final BigInt getRecommendPlaylist = BigInt.one << 27;
  static final BigInt getNewSongTabList = BigInt.one << 28;
  static final BigInt getNewSongList = BigInt.one << 29;
  static final BigInt getNewAlbumTabList = BigInt.one << 30;
  static final BigInt getNewAlbumList = BigInt.one << 31;
  static final BigInt getRecommendPage = BigInt.one << 32;
  static final BigInt getDiscoverPage = BigInt.one << 33;
  static final BigInt buildSourceUrl = BigInt.one << 34;
  static final BigInt parseSourceUrl = BigInt.one << 35;
  static final BigInt searchAudiobook = BigInt.one << 36;
  static final BigInt listArtistTabs = BigInt.one << 37;
  static final BigInt listTabArtists = BigInt.one << 38;
  static final BigInt listRadios = BigInt.one << 39;
  static final BigInt listRadioSongs = BigInt.one << 40;
  static final BigInt listArtistPhotos = BigInt.one << 41;
  static final BigInt listMvFilters = BigInt.one << 42;
  static final BigInt listFilterMvs = BigInt.one << 43;
  static final BigInt getSongDetail = BigInt.one << 44;
  static final BigInt listSongRelations = BigInt.one << 45;
  static final BigInt listMVFeeds = BigInt.one << 46;
  static final BigInt getSearchDefault = BigInt.one << 47;
  static final BigInt searchLyric = BigInt.one << 48;
}

class OnlinePlatform {
  const OnlinePlatform({
    required this.id,
    required this.name,
    required this.shortName,
    required this.status,
    required this.featureSupportFlag,
    this.imageSizes = const <int>[],
    this.qualities = const <String, String>{},
  });

  final String id;
  final String name;
  final String shortName;
  final int status;
  final BigInt featureSupportFlag;
  final List<int> imageSizes;
  final Map<String, String> qualities;

  bool get available => status == 1;

  bool supports(BigInt flag) {
    return (featureSupportFlag & flag) != BigInt.zero;
  }

  factory OnlinePlatform.fromMap(Map<String, dynamic> raw) {
    final id = '${raw['id'] ?? ''}'.trim();
    final name = '${raw['name'] ?? ''}'.trim();
    if (id.isEmpty || name.isEmpty) {
      throw FormatException('Invalid platform payload: $raw');
    }
    return OnlinePlatform(
      id: id,
      name: name,
      shortName: _readShortName(raw, name),
      status: _readStatus(raw),
      featureSupportFlag: _readFeatureSupportFlag(raw),
      imageSizes: _readImageSizes(raw),
      qualities: _readQualities(raw),
    );
  }

  static String _readShortName(Map<String, dynamic> raw, String fallback) {
    final shortName = '${raw['shortname'] ?? ''}'.trim();
    if (shortName.isEmpty) {
      return fallback;
    }
    return shortName;
  }

  static int _readStatus(Map<String, dynamic> raw) {
    final status = raw['status'];
    if (status is int) {
      return status;
    }
    return int.tryParse('$status') ?? 0;
  }

  static BigInt _readFeatureSupportFlag(Map<String, dynamic> raw) {
    final flag = raw['feature_support_flag'];
    if (flag is BigInt) {
      return flag;
    }
    if (flag is int) {
      return BigInt.from(flag);
    }
    final parsed = BigInt.tryParse('$flag');
    return parsed ?? BigInt.zero;
  }

  static List<int> _readImageSizes(Map<String, dynamic> raw) {
    final value = raw['image_sizes'] ?? raw['imageSizes'];
    if (value is List) {
      final result = value
          .map((e) => e is int ? e : int.tryParse('$e'))
          .whereType<int>()
          .where((e) => e > 0)
          .toList(growable: false);
      if (result.isEmpty) return const <int>[];
      final unique = <int>{...result}.toList()..sort();
      return unique;
    }
    return const <int>[];
  }

  static Map<String, String> _readQualities(Map<String, dynamic> raw) {
    final value = raw['qualities'];
    if (value is! List) {
      return const <String, String>{};
    }
    final result = <String, String>{};
    for (final item in value) {
      if (item is! Map) {
        continue;
      }
      final name = '${item['name'] ?? ''}'.trim();
      final description = '${item['description'] ?? ''}'.trim();
      if (name.isEmpty) {
        continue;
      }
      result[name] = description;
    }
    return result;
  }
}
