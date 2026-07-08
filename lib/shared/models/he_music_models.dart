class LinkInfo {
  const LinkInfo({
    required this.name,
    required this.quality,
    required this.format,
    required this.size,
    required this.url,
  });

  final String name;
  final int quality;
  final String format;
  final String size;
  final String url;

  String get qualityLabel {
    if (name.trim().isNotEmpty) {
      return name.trim().toUpperCase();
    }
    if (quality > 0) {
      return '${quality}P';
    }
    return format.toUpperCase();
  }

  String get cacheKey => '$quality|$format|$url';

  factory LinkInfo.fromMap(Map<String, dynamic> raw) {
    return LinkInfo(
      name: _string(raw['name']),
      quality: _int(raw['quality']),
      format: _string(raw['format']),
      size: _string(raw['size']),
      url: _string(raw['url']),
    );
  }
}

class SongInfoArtistInfo {
  const SongInfoArtistInfo({required this.id, required this.name});

  final String id;
  final String name;

  factory SongInfoArtistInfo.fromMap(Map<String, dynamic> raw) {
    return SongInfoArtistInfo(
      id: _string(raw['id']),
      name: _string(raw['name']),
    );
  }
}

class SongInfoAlbumInfo {
  const SongInfoAlbumInfo({required this.name, required this.id});

  final String name;
  final String id;

  factory SongInfoAlbumInfo.fromMap(Map<String, dynamic> raw) {
    return SongInfoAlbumInfo(
      name: _string(raw['name']),
      id: _string(raw['id']),
    );
  }
}

class IdPlatformInfo {
  const IdPlatformInfo({required this.id, required this.platform});

  final String id;
  final String platform;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'id': id, 'platform': platform};
  }

  factory IdPlatformInfo.fromMap(Map<String, dynamic> raw) {
    return IdPlatformInfo(
      id: _string(raw['id']),
      platform: _string(raw['platform']),
    );
  }
}

class SongInfo {
  const SongInfo({
    required this.name,
    required this.subtitle,
    required this.id,
    required this.duration,
    required this.mvId,
    required this.album,
    required this.artists,
    required this.links,
    required this.platform,
    required this.cover,
    required this.sublist,
    required this.originalType,
    this.path,
    this.size,
    this.quality,
    this.alias,
  });

  final String name;
  final String subtitle;
  final String id;
  final int duration;
  final String mvId;
  final SongInfoAlbumInfo? album;
  final List<SongInfoArtistInfo> artists;
  final List<LinkInfo> links;
  final String platform;
  final String cover;
  final List<SongInfo> sublist;
  final int originalType;
  final String? path;
  final int? size;
  final String? quality;
  final String? alias;

  String get title => name;

  String get displaySubtitle {
    final primary = subtitle.trim();
    if (primary.isNotEmpty) {
      return primary;
    }
    final fallback = alias?.trim() ?? '';
    return fallback;
  }

  String get artist {
    final names = artists
        .map((item) => item.name.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (names.isNotEmpty) {
      return names.join(' / ');
    }
    return '-';
  }

  bool get hasMv => mvId.isNotEmpty && mvId != '0';

  String get artistAlbumText {
    final artistText = artist.trim();
    final albumText = album?.name.trim() ?? '';
    if (artistText.isEmpty || artistText == '-') {
      return albumText.isEmpty ? '-' : albumText;
    }
    if (albumText.isEmpty) {
      return artistText;
    }
    return '$artistText - $albumText';
  }

  factory SongInfo.fromMap(
    Map<String, dynamic> raw, {
    String fallbackPlatform = '',
  }) {
    return SongInfo(
      name: _string(raw['name'] ?? raw['title']),
      subtitle: _string(raw['subtitle']),
      id: _string(raw['id']),
      duration: _int(raw['duration']),
      mvId: _string(raw['mv_id']),
      album: _album(raw['album']),
      artists: _artists(raw['artists'] ?? raw['artist']),
      links: _links(raw['links']),
      platform: _string(raw['platform']).isEmpty
          ? fallbackPlatform
          : _string(raw['platform']),
      cover: _cover(raw),
      sublist: _songs(raw['sublist'], fallbackPlatform),
      originalType: _int(raw['original_type']),
      path: _nullableString(raw['path']),
      size: _nullableInt(raw['size']),
      quality: _nullableString(raw['quality']),
      alias: _nullableString(raw['alias']),
    );
  }
}

class RadioInfo {
  const RadioInfo({
    required this.name,
    required this.id,
    required this.cover,
    required this.platform,
  });

  final String name;
  final String id;
  final String cover;
  final String platform;

  factory RadioInfo.fromMap(
    Map<String, dynamic> raw, {
    String fallbackPlatform = '',
  }) {
    return RadioInfo(
      name: _string(raw['name']),
      id: _string(raw['id']),
      cover: _cover(raw),
      platform: _platform(raw, fallbackPlatform),
    );
  }
}

class RadioGroupInfo {
  const RadioGroupInfo({
    required this.name,
    required this.radios,
    required this.platform,
  });

  final String name;
  final List<RadioInfo> radios;
  final String platform;

  factory RadioGroupInfo.fromMap(
    Map<String, dynamic> raw, {
    String fallbackPlatform = '',
  }) {
    final platform = _platform(raw, fallbackPlatform);
    return RadioGroupInfo(
      name: _string(raw['name']),
      radios: _radios(raw['radios'], platform),
      platform: platform,
    );
  }
}

class ArtistInfo {
  const ArtistInfo({
    required this.id,
    required this.name,
    required this.cover,
    required this.platform,
    required this.description,
    required this.mvCount,
    required this.songCount,
    required this.albumCount,
    required this.alias,
  });

  final String id;
  final String name;
  final String cover;
  final String platform;
  final String description;
  final String mvCount;
  final String songCount;
  final String albumCount;
  final String alias;

  factory ArtistInfo.fromMap(
    Map<String, dynamic> raw, {
    String fallbackPlatform = '',
  }) {
    return ArtistInfo(
      id: _string(raw['id']),
      name: _string(raw['name']),
      cover: _cover(raw),
      platform: _platform(raw, fallbackPlatform),
      description: _string(raw['description']),
      mvCount: _countText(
        raw['mv_count'] ?? raw['mvCount'] ?? raw['video_count'],
      ),
      songCount: _countText(raw['song_count'] ?? raw['songCount']),
      albumCount: _countText(raw['album_count'] ?? raw['albumCount']),
      alias: _string(raw['alias']),
    );
  }
}

class FilterOptionInfo {
  const FilterOptionInfo({required this.value, required this.label});

  final String value;
  final String label;

  factory FilterOptionInfo.fromMap(Map<String, dynamic> raw) {
    return FilterOptionInfo(
      value: _string(raw['value']),
      label: _string(raw['label']),
    );
  }
}

class FilterInfo {
  const FilterInfo({
    required this.id,
    required this.platform,
    required this.options,
  });

  final String id;
  final String platform;
  final List<FilterOptionInfo> options;

  factory FilterInfo.fromMap(
    Map<String, dynamic> raw, {
    String fallbackPlatform = '',
  }) {
    return FilterInfo(
      id: _string(raw['id']),
      platform: _platform(raw, fallbackPlatform),
      options: _filterOptions(raw['options']),
    );
  }
}

class CategoryInfo {
  const CategoryInfo({
    required this.name,
    required this.id,
    this.platform = '',
  });

  final String name;
  final String id;
  final String platform;

  factory CategoryInfo.fromMap(
    Map<String, dynamic> raw, {
    String fallbackPlatform = '',
  }) {
    final platform = _string(raw['platform']);
    return CategoryInfo(
      name: _string(raw['name']),
      id: _string(raw['id']),
      platform: platform.isEmpty ? fallbackPlatform : platform,
    );
  }
}

class PlaylistInfo {
  const PlaylistInfo({
    required this.name,
    required this.id,
    required this.cover,
    required this.creator,
    required this.songCount,
    required this.playCount,
    required this.songs,
    required this.platform,
    required this.description,
    this.categories = const <CategoryInfo>[],
    this.isDefault = false,
  });

  final String name;
  final String id;
  final String cover;
  final String creator;
  final String songCount;
  final String playCount;
  final List<SongInfo> songs;
  final String platform;
  final String description;
  final List<CategoryInfo> categories;
  final bool isDefault;

  factory PlaylistInfo.fromMap(
    Map<String, dynamic> raw, {
    String fallbackPlatform = '',
  }) {
    return PlaylistInfo(
      name: _string(raw['name']),
      id: _string(raw['id']),
      cover: _cover(raw),
      creator: _string(raw['creator']),
      songCount: _countText(raw['song_count'] ?? raw['songCount']),
      playCount: _countText(raw['play_count'] ?? raw['playCount']),
      songs: _songs(raw['songs'], fallbackPlatform),
      platform: _platform(raw, fallbackPlatform),
      description: _string(raw['description']),
      categories: _categories(raw['categories']),
      isDefault: _int(raw['is_default']) == 1 || _bool(raw['is_default']),
    );
  }
}

class AlbumInfo {
  const AlbumInfo({
    required this.name,
    required this.id,
    required this.cover,
    required this.artists,
    required this.songCount,
    required this.publishTime,
    required this.songs,
    required this.description,
    required this.platform,
    required this.language,
    required this.genre,
    required this.type,
    required this.isFinished,
    required this.playCount,
  });

  final String name;
  final String id;
  final String cover;
  final List<SongInfoArtistInfo> artists;
  final String songCount;
  final String publishTime;
  final List<SongInfo> songs;
  final String description;
  final String platform;
  final String language;
  final String genre;
  final int type;
  final bool isFinished;
  final String playCount;

  String get artistText {
    final names = artists
        .map((item) => item.name.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (names.isEmpty) {
      return '-';
    }
    return names.join(' / ');
  }

  factory AlbumInfo.fromMap(
    Map<String, dynamic> raw, {
    String fallbackPlatform = '',
  }) {
    return AlbumInfo(
      name: _string(raw['name']),
      id: _string(raw['id']),
      cover: _cover(raw),
      artists: _artists(raw['artists'] ?? raw['artist']),
      songCount: _countText(raw['song_count'] ?? raw['songCount']),
      publishTime: _string(raw['publish_time'] ?? raw['publishTime']),
      songs: _songs(raw['songs'], fallbackPlatform),
      description: _string(raw['description']),
      platform: _platform(raw, fallbackPlatform),
      language: _string(raw['language']),
      genre: _string(raw['genre']),
      type: _int(raw['type']),
      isFinished: _bool(raw['is_finished']),
      playCount: _countText(raw['play_count'] ?? raw['playCount']),
    );
  }
}

class MvInfo {
  const MvInfo({
    required this.platform,
    required this.links,
    required this.id,
    required this.name,
    required this.cover,
    required this.type,
    required this.playCount,
    required this.creator,
    required this.duration,
    required this.description,
  });

  final String platform;
  final List<LinkInfo> links;
  final String id;
  final String name;
  final String cover;
  final int type;
  final String playCount;
  final String creator;
  final int duration;
  final String description;

  factory MvInfo.fromMap(
    Map<String, dynamic> raw, {
    String fallbackPlatform = '',
  }) {
    return MvInfo(
      platform: _platform(raw, fallbackPlatform),
      links: _links(raw['links']),
      id: _string(raw['id']),
      name: _string(raw['name']),
      cover: _cover(raw),
      type: _int(raw['type']),
      playCount: _countText(raw['play_count'] ?? raw['playCount']),
      creator: _string(raw['creator']),
      duration: _int(raw['duration']),
      description: _string(raw['description']),
    );
  }
}

SongInfoAlbumInfo? _album(dynamic value) {
  if (value is Map<String, dynamic>) {
    return SongInfoAlbumInfo.fromMap(value);
  }
  if (value is Map) {
    return SongInfoAlbumInfo.fromMap(
      value.map((key, item) => MapEntry('$key', item)),
    );
  }
  final text = _string(value);
  if (text.isEmpty) {
    return null;
  }
  return SongInfoAlbumInfo(name: text, id: '');
}

List<SongInfoArtistInfo> _artists(dynamic value) {
  if (value is List) {
    return value
        .map((item) {
          if (item is Map<String, dynamic>) {
            return SongInfoArtistInfo.fromMap(item);
          }
          if (item is Map) {
            return SongInfoArtistInfo.fromMap(
              item.map((key, entry) => MapEntry('$key', entry)),
            );
          }
          final name = '$item'.trim();
          return SongInfoArtistInfo(id: '', name: name);
        })
        .where((item) => item.name.isNotEmpty)
        .toList(growable: false);
  }
  final text = _string(value);
  if (text.isEmpty) {
    return const <SongInfoArtistInfo>[];
  }
  return <SongInfoArtistInfo>[SongInfoArtistInfo(id: '', name: text)];
}

List<FilterOptionInfo> _filterOptions(dynamic value) {
  if (value is! List) {
    return const <FilterOptionInfo>[];
  }
  return value
      .map((item) {
        if (item is Map<String, dynamic>) {
          return FilterOptionInfo.fromMap(item);
        }
        if (item is Map) {
          return FilterOptionInfo.fromMap(
            item.map((key, entry) => MapEntry('$key', entry)),
          );
        }
        return FilterOptionInfo(value: '', label: '$item'.trim());
      })
      .where((item) => item.value.isNotEmpty || item.label.isNotEmpty)
      .toList(growable: false);
}

List<LinkInfo> _links(dynamic value) {
  if (value is! List) {
    return const <LinkInfo>[];
  }
  return value
      .map((item) {
        if (item is Map<String, dynamic>) {
          return LinkInfo.fromMap(item);
        }
        if (item is Map) {
          return LinkInfo.fromMap(
            item.map((key, entry) => MapEntry('$key', entry)),
          );
        }
        return const LinkInfo(
          name: '',
          quality: 0,
          format: '',
          size: '',
          url: '',
        );
      })
      .where((item) => item.quality > 0 || item.url.isNotEmpty)
      .toList(growable: false);
}

List<CategoryInfo> _categories(dynamic value) {
  if (value is! List) {
    return const <CategoryInfo>[];
  }
  return value
      .map((item) {
        if (item is Map<String, dynamic>) {
          return CategoryInfo.fromMap(item);
        }
        if (item is Map) {
          return CategoryInfo.fromMap(
            item.map((key, entry) => MapEntry('$key', entry)),
          );
        }
        final name = '$item'.trim();
        return CategoryInfo(name: name, id: '');
      })
      .where((item) => item.name.isNotEmpty)
      .toList(growable: false);
}

List<RadioInfo> _radios(dynamic value, String fallbackPlatform) {
  if (value is! List) {
    return const <RadioInfo>[];
  }
  return value
      .map((item) {
        if (item is Map<String, dynamic>) {
          return RadioInfo.fromMap(item, fallbackPlatform: fallbackPlatform);
        }
        if (item is Map) {
          return RadioInfo.fromMap(
            item.map((key, entry) => MapEntry('$key', entry)),
            fallbackPlatform: fallbackPlatform,
          );
        }
        return RadioInfo(
          name: '',
          id: '',
          cover: '',
          platform: fallbackPlatform,
        );
      })
      .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
      .toList(growable: false);
}

List<SongInfo> _songs(dynamic value, String fallbackPlatform) {
  if (value is! List) {
    return const <SongInfo>[];
  }
  return value
      .map((item) {
        if (item is Map<String, dynamic>) {
          return SongInfo.fromMap(item, fallbackPlatform: fallbackPlatform);
        }
        if (item is Map) {
          return SongInfo.fromMap(
            item.map((key, entry) => MapEntry('$key', entry)),
            fallbackPlatform: fallbackPlatform,
          );
        }
        return SongInfo(
          name: '',
          subtitle: '',
          id: '',
          duration: 0,
          mvId: '',
          album: null,
          artists: const <SongInfoArtistInfo>[],
          links: const <LinkInfo>[],
          platform: fallbackPlatform,
          cover: '',
          sublist: const <SongInfo>[],
          originalType: 0,
        );
      })
      .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
      .toList(growable: false);
}

String _cover(Map<String, dynamic> raw) {
  const keys = <String>['cover', 'pic', 'imgurl', 'image', 'thumb'];
  for (final key in keys) {
    final value = _string(raw[key]);
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

String _platform(Map<String, dynamic> raw, String fallbackPlatform) {
  final platform = _string(raw['platform']);
  if (platform.isNotEmpty) {
    return platform;
  }
  return fallbackPlatform;
}

String _string(dynamic value) => '${value ?? ''}'.trim();

String? _nullableString(dynamic value) {
  final result = _string(value);
  if (result.isEmpty) {
    return null;
  }
  return result;
}

int _int(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse('${value ?? ''}') ?? 0;
}

String _countText(dynamic value) {
  final parsed = int.tryParse('${value ?? ''}');
  if (parsed == null || parsed < 0) {
    return '0';
  }
  return '$parsed';
}

bool _bool(dynamic value) {
  if (value is bool) {
    return value;
  }
  final parsed = '${value ?? ''}'.trim().toLowerCase();
  return parsed == 'true' || parsed == '1';
}

int? _nullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  final result = _int(value);
  if (result == 0 && '${value ?? ''}'.trim().isEmpty) {
    return null;
  }
  return result;
}
