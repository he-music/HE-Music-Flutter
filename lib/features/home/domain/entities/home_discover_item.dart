import '../../../../shared/models/he_music_models.dart';

enum HomeDiscoverItemType { song, album, playlist, video }

class HomeDiscoverItem {
  const HomeDiscoverItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.type,
    this.songInfo,
    this.originalType = 0,
    this.mvId,
    this.playCount,
    this.songCount,
    this.creator,
    this.duration,
  });

  final String id;
  final String title;
  final String subtitle;
  final String coverUrl;
  final HomeDiscoverItemType type;
  final SongInfo? songInfo;
  final int originalType;
  final String? mvId;
  final String? playCount;
  final String? songCount;
  final String? creator;
  final String? duration;

  bool get isOriginal => originalType == 1;

  factory HomeDiscoverItem.fromMap(
    Map<String, dynamic> raw,
    HomeDiscoverItemType type, {
    String fallbackPlatform = '',
  }) {
    final id = '${raw['id'] ?? ''}'.trim();
    final title = '${raw['name'] ?? ''}'.trim();
    if (id.isEmpty || title.isEmpty) {
      throw FormatException('Invalid discover item payload: $raw');
    }
    final songInfo = type == HomeDiscoverItemType.song
        ? SongInfo.fromMap(raw, fallbackPlatform: fallbackPlatform)
        : null;
    return HomeDiscoverItem(
      id: songInfo?.id ?? id,
      title: songInfo?.title ?? title,
      subtitle: songInfo?.artist ?? _readSubtitle(raw, type),
      coverUrl: (songInfo?.cover ?? '').trim().isNotEmpty
          ? songInfo!.cover
          : _readCoverUrl(raw),
      type: type,
      songInfo: songInfo,
      originalType: songInfo?.originalType ?? _readOriginalType(raw, type),
      mvId: (songInfo?.mvId ?? '').trim().isNotEmpty
          ? songInfo!.mvId
          : _readMvId(raw, type),
      playCount: _readPlayCount(raw, type),
      songCount: _readSongCount(raw, type),
      creator: _readCreator(raw, type),
      duration: _readDuration(raw, type),
    );
  }

  static String _readSubtitle(
    Map<String, dynamic> raw,
    HomeDiscoverItemType type,
  ) {
    if (type == HomeDiscoverItemType.song ||
        type == HomeDiscoverItemType.album) {
      return _readArtists(raw);
    }
    if (type == HomeDiscoverItemType.video) {
      return '${raw['duration'] ?? '-'}';
    }
    return '${raw['play_count'] ?? raw['id'] ?? '-'}';
  }

  static String _readArtists(Map<String, dynamic> raw) {
    final artists = raw['artists'];
    if (artists is List) {
      final names = artists
          .map((item) => item is Map ? '${item['name'] ?? ''}'.trim() : '$item')
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
      if (names.isNotEmpty) {
        return names.join(' / ');
      }
    }
    final fallback = '${raw['artists'] ?? ''}'.trim();
    return fallback.isEmpty ? '-' : fallback;
  }

  static String _readCoverUrl(Map<String, dynamic> raw) {
    final keys = <String>['cover', 'pic', 'imgurl', 'image', 'thumb'];
    for (final key in keys) {
      final value = '${raw[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static String? _readPlayCount(
    Map<String, dynamic> raw,
    HomeDiscoverItemType type,
  ) {
    if (type != HomeDiscoverItemType.playlist &&
        type != HomeDiscoverItemType.video) {
      return null;
    }
    final value = '${raw['play_count'] ?? ''}'.trim();
    if (value.isEmpty || value == '-') {
      return null;
    }
    return value;
  }

  static String? _readCreator(
    Map<String, dynamic> raw,
    HomeDiscoverItemType type,
  ) {
    if (type != HomeDiscoverItemType.video) {
      return null;
    }
    final creator = '${raw['creator'] ?? ''}'.trim();
    if (creator.isNotEmpty) {
      return creator;
    }
    final artists = raw['artists'];
    if (artists is List) {
      final names = artists
          .map((item) => item is Map ? '${item['name'] ?? ''}'.trim() : '$item')
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
      if (names.isNotEmpty) {
        return names.join(' / ');
      }
    }
    return null;
  }

  static String? _readSongCount(
    Map<String, dynamic> raw,
    HomeDiscoverItemType type,
  ) {
    if (type != HomeDiscoverItemType.playlist) {
      return null;
    }
    final value = '${raw['song_count'] ?? raw['songCount'] ?? ''}'.trim();
    if (value.isEmpty || value == '-') {
      return null;
    }
    return value;
  }

  static String? _readDuration(
    Map<String, dynamic> raw,
    HomeDiscoverItemType type,
  ) {
    if (type != HomeDiscoverItemType.video) {
      return null;
    }
    final value = '${raw['duration'] ?? ''}'.trim();
    if (value.isEmpty || value == '-') {
      return null;
    }
    return value;
  }

  static int _readOriginalType(
    Map<String, dynamic> raw,
    HomeDiscoverItemType type,
  ) {
    if (type != HomeDiscoverItemType.song) {
      return 0;
    }
    return int.tryParse('${raw['original_type'] ?? '0'}') ?? 0;
  }

  static String? _readMvId(
    Map<String, dynamic> raw,
    HomeDiscoverItemType type,
  ) {
    if (type != HomeDiscoverItemType.song) {
      return null;
    }
    final value = '${raw['mv_id'] ?? ''}'.trim();
    if (value.isEmpty || value == '0' || value == '-') {
      return null;
    }
    return value;
  }
}
