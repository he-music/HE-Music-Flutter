import 'package:dio/dio.dart';

import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/my_favorite_item.dart';
import '../../domain/entities/my_favorite_type.dart';

const _defaultPageSize = 1000;
const _defaultPageIndex = 1;

class MyCollectionApiClient {
  const MyCollectionApiClient(this._dio);

  final Dio _dio;

  Future<List<MyFavoriteItem>> fetchFavorites(MyFavoriteType type) async {
    final response = await _dio.get(
      _listPath(type),
      queryParameters: const <String, dynamic>{
        'page_size': _defaultPageSize,
        'page_index': _defaultPageIndex,
      },
    );
    final payload = _asMap(response.data);
    final list = payload['list'];
    if (list is! List) {
      return const <MyFavoriteItem>[];
    }
    if (type == MyFavoriteType.songs) {
      return _fetchSongFavorites(list);
    }
    return list.map((item) => _toItem(type, item)).toList(growable: false);
  }

  Future<List<IdPlatformInfo>> fetchFavoriteIdPlatforms(
    MyFavoriteType type,
  ) async {
    final response = await _dio.get(
      _listPath(type),
      queryParameters: const <String, dynamic>{
        'page_size': _defaultPageSize,
        'page_index': _defaultPageIndex,
      },
    );
    final payload = _asMap(response.data);
    final list = payload['list'];
    if (list is! List) {
      return const <IdPlatformInfo>[];
    }
    return list
        .map((item) => IdPlatformInfo.fromMap(_asMap(item)))
        .where((item) => item.id.isNotEmpty && item.platform.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<MyFavoriteItem>> fetchCreatedPlaylists() async {
    final response = await _dio.get(
      '/v1/user/playlists',
      queryParameters: const <String, dynamic>{
        'page_size': _defaultPageSize,
        'page_index': _defaultPageIndex,
      },
    );
    final payload = _asMap(response.data);
    final list = payload['list'];
    if (list is! List) {
      return const <MyFavoriteItem>[];
    }
    return list
        .map((item) {
          final raw = _asMap(item);
          return MyFavoriteItem.fromPlaylistInfo(
            playlist: PlaylistInfo(
              name: _asString(raw['name']),
              id: _asString(raw['id']),
              cover: _asString(raw['cover']),
              creator: _asString(raw['creator']),
              songCount: _asCount(raw['song_count']),
              playCount: _asCount(raw['play_count']),
              songs: const <SongInfo>[],
              platform: _asString(raw['platform']),
              description: _asString(raw['description']),
              isDefault: _asDefault(raw['is_default']),
            ),
            type: MyFavoriteType.playlists,
          );
        })
        .toList(growable: false);
  }

  Future<void> removeFavorite({
    required MyFavoriteType type,
    required String id,
    required String platform,
  }) async {
    await _dio.delete(
      _singlePath(type),
      data: <String, dynamic>{'id': id, 'platform': platform},
    );
  }

  bool _asDefault(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value.toInt() == 1;
    }
    final text = '$value'.trim().toLowerCase();
    return text == '1' || text == 'true';
  }

  String _listPath(MyFavoriteType type) {
    return switch (type) {
      MyFavoriteType.songs => '/v1/user/favourite/songs',
      MyFavoriteType.playlists => '/v1/user/favourite/playlists',
      MyFavoriteType.artists => '/v1/user/favourite/artists',
      MyFavoriteType.albums => '/v1/user/favourite/albums',
    };
  }

  String _singlePath(MyFavoriteType type) {
    return switch (type) {
      MyFavoriteType.songs => '/v1/user/favourite/song',
      MyFavoriteType.playlists => '/v1/user/favourite/playlist',
      MyFavoriteType.artists => '/v1/user/favourite/artist',
      MyFavoriteType.albums => '/v1/user/favourite/album',
    };
  }

  Future<List<MyFavoriteItem>> _fetchSongFavorites(List rawList) async {
    final items = rawList.map(_asMap).toList(growable: false);
    final groupedIds = _groupSongIdsByPlatform(items);
    final detailMapByPlatform = await _fetchSongDetails(groupedIds);
    return items
        .map((item) {
          final id = _asString(item['id']);
          final platform = _asString(item['platform']);
          final detail = detailMapByPlatform[platform]?[id];
          if (detail != null) {
            return MyFavoriteItem.fromSongInfo(
              song: SongInfo.fromMap(detail, fallbackPlatform: platform),
              type: MyFavoriteType.songs,
            );
          }
          return MyFavoriteItem(
            id: id,
            platform: platform,
            type: MyFavoriteType.songs,
            title: 'ID: $id',
            subtitle: platform.isEmpty ? '-' : platform,
            coverUrl: '',
          );
        })
        .toList(growable: false);
  }

  Map<String, List<String>> _groupSongIdsByPlatform(
    List<Map<String, dynamic>> items,
  ) {
    final grouped = <String, List<String>>{};
    for (final item in items) {
      final id = _asString(item['id']);
      final platform = _asString(item['platform']);
      if (id.isEmpty || platform.isEmpty) {
        continue;
      }
      grouped.putIfAbsent(platform, () => <String>[]).add(id);
    }
    return grouped;
  }

  Future<Map<String, Map<String, Map<String, dynamic>>>> _fetchSongDetails(
    Map<String, List<String>> groupedIds,
  ) async {
    final entries = groupedIds.entries.toList(growable: false);
    final detailFutures = entries.map((entry) async {
      final list = await _fetchSongDetailsByPlatform(
        platform: entry.key,
        ids: entry.value,
      );
      return MapEntry(entry.key, list);
    });
    final detailEntries = await Future.wait(detailFutures);
    return Map<String, Map<String, Map<String, dynamic>>>.fromEntries(
      detailEntries,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _fetchSongDetailsByPlatform({
    required String platform,
    required List<String> ids,
  }) async {
    final response = await _dio.get(
      '/v1/song',
      queryParameters: <String, dynamic>{'ids': ids, 'platform': platform},
    );
    final payload = _asMap(response.data);
    final list = payload['list'];
    if (list is! List) {
      return <String, Map<String, dynamic>>{};
    }
    final entries = list.map((item) {
      final detail = _asMap(item);
      return MapEntry(_asString(detail['id']), detail);
    });
    return Map<String, Map<String, dynamic>>.fromEntries(entries);
  }

  MyFavoriteItem _toItem(MyFavoriteType type, dynamic value) {
    final map = _asMap(value);
    return switch (type) {
      MyFavoriteType.playlists => MyFavoriteItem.fromPlaylistInfo(
        playlist: PlaylistInfo(
          name: _asString(map['name']),
          id: _asString(map['id']),
          cover: _asString(map['cover']),
          creator: _asString(map['creator']),
          songCount: _asCount(map['song_count']),
          playCount: _asCount(map['play_count']),
          songs: const <SongInfo>[],
          platform: _asString(map['platform']),
          description: _asString(map['description']),
        ),
        type: type,
      ),
      MyFavoriteType.albums => MyFavoriteItem.fromAlbumInfo(
        album: AlbumInfo(
          name: _asString(map['name']),
          id: _asString(map['id']),
          cover: _asString(map['cover']),
          artists: _artists(map['artists']),
          songCount: _asCount(map['song_count']),
          publishTime: _asString(map['publish_time']),
          songs: const <SongInfo>[],
          description: _asString(map['description']),
          platform: _asString(map['platform']),
          language: _asString(map['language']),
          genre: _asString(map['genre']),
          type: _asInt(map['type']),
          isFinished: _asBool(map['is_finished']),
          playCount: _asCount(map['play_count']),
        ),
        type: type,
      ),
      MyFavoriteType.artists => MyFavoriteItem.fromArtistInfo(
        artist: ArtistInfo(
          id: _asString(map['id']),
          name: _asString(map['name']),
          cover: _asString(map['cover']),
          platform: _asString(map['platform']),
          description: _asString(map['description']),
          mvCount: _asCount(map['mv_count']),
          songCount: _asCount(map['song_count']),
          albumCount: _asCount(map['album_count']),
          alias: _asString(map['alias']),
        ),
        type: type,
      ),
      MyFavoriteType.songs => MyFavoriteItem(
        id: _asString(map['id']),
        platform: _asString(map['platform']),
        type: type,
        title: _asString(map['name']),
        subtitle: _asString(map['platform']),
        coverUrl: _asString(map['cover']),
      ),
    };
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entry) => MapEntry('$key', entry));
    }
    return <String, dynamic>{};
  }

  String _asString(dynamic value) {
    if (value == null) {
      return '';
    }
    return '$value';
  }

  String _asCount(dynamic value) {
    final parsed = int.tryParse('${value ?? ''}');
    if (parsed == null || parsed < 0) {
      return '0';
    }
    return '$parsed';
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    final parsed = '${value ?? ''}'.trim().toLowerCase();
    return parsed == 'true' || parsed == '1';
  }

  List<SongInfoArtistInfo> _artists(dynamic value) {
    if (value is! List) {
      return const <SongInfoArtistInfo>[];
    }
    return value
        .map((entry) {
          final map = _asMap(entry);
          return SongInfoArtistInfo(
            id: _asString(map['id']),
            name: _asString(map['name']),
          );
        })
        .where((entry) => entry.name.isNotEmpty)
        .toList(growable: false);
  }
}
