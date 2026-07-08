import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/artist_detail_album.dart';
import '../../domain/entities/artist_detail_content.dart';
import '../../domain/entities/artist_detail_page_chunk.dart';
import '../../domain/entities/artist_detail_request.dart';
import '../../domain/entities/artist_detail_song.dart';
import '../../domain/entities/artist_detail_video.dart';

class ArtistDetailApiClient {
  const ArtistDetailApiClient(this._dio);

  final Dio _dio;

  Future<ArtistDetailContent> fetchDetail(ArtistDetailRequest request) async {
    final response = await _dio.get(
      '/v1/artist',
      queryParameters: <String, dynamic>{
        'id': request.id,
        'platform': request.platform,
      },
    );
    final raw = _asMap(response.data);
    return ArtistDetailContent(
      info: ArtistInfo(
        id: request.id,
        name: _title(raw, request.title),
        cover: _cover(raw),
        platform: request.platform,
        description: _description(raw),
        mvCount: _count(raw, const <String>[
          'mv_count',
          'mvCount',
          'video_count',
        ]),
        songCount: _count(raw, const <String>['song_count', 'songCount']),
        albumCount: _count(raw, const <String>['album_count', 'albumCount']),
        alias: _subtitle(raw),
      ),
      songs: _songs(raw, request.platform),
    );
  }

  Future<List<ArtistDetailSong>> fetchSongs(ArtistDetailRequest request) async {
    final list = await _fetchAllPages(
      (pageIndex) => fetchSongsPage(request, pageIndex: pageIndex),
    );
    return list;
  }

  Future<ArtistDetailPageChunk<ArtistDetailSong>> fetchSongsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    final response = await _fetchPage(
      path: '/v1/artist/songs',
      request: request,
      pageSize: 500,
      pageIndex: pageIndex,
    );
    final list = response.items;
    final items = list
        .map((item) {
          final song = _asMap(item);
          final id = '${song['id'] ?? ''}'.trim();
          final name = '${song['name'] ?? ''}'.trim();
          if (id.isEmpty || name.isEmpty) {
            throw AppException(
              NetworkFailure('Invalid song item in artist songs payload.'),
            );
          }
          return SongInfo.fromMap(song, fallbackPlatform: request.platform);
        })
        .toList(growable: false);
    return ArtistDetailPageChunk<ArtistDetailSong>(
      items: items,
      hasMore: response.hasMore,
      nextPageIndex: response.nextPageIndex,
    );
  }

  Future<List<ArtistDetailAlbum>> fetchAlbums(
    ArtistDetailRequest request,
  ) async {
    final list = await _fetchAllPages(
      (pageIndex) => fetchAlbumsPage(request, pageIndex: pageIndex),
    );
    return list;
  }

  Future<ArtistDetailPageChunk<ArtistDetailAlbum>> fetchAlbumsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    final response = await _fetchPage(
      path: '/v1/artist/albums',
      request: request,
      pageSize: 200,
      pageIndex: pageIndex,
    );
    final list = response.items;
    final items = list
        .map((item) {
          final album = _asMap(item);
          final id = '${album['id'] ?? ''}'.trim();
          final name = '${album['name'] ?? ''}'.trim();
          if (id.isEmpty || name.isEmpty) {
            throw AppException(
              NetworkFailure('Invalid album item in artist albums payload.'),
            );
          }
          return ArtistDetailAlbum(
            name: name,
            id: id,
            cover: _cover(album),
            artists: _artists(album['artists']),
            songCount: _count(album, const <String>[
              'song_count',
              'songCount',
              'trackCount',
            ]),
            publishTime: _firstText(album, const <String>[
              'publish_time',
              'publishTime',
              'createTime',
            ]),
            songs: const <SongInfo>[],
            description: _firstText(album, const <String>['description']),
            platform: _platformOf(album, request.platform),
            language: _firstText(album, const <String>['language']),
            genre: _firstText(album, const <String>['genre']),
            type: _toInt(album['type']),
            isFinished: _readBool(album['is_finished']),
            playCount: _count(album, const <String>['play_count', 'playCount']),
          );
        })
        .toList(growable: false);
    return ArtistDetailPageChunk<ArtistDetailAlbum>(
      items: items,
      hasMore: response.hasMore,
      nextPageIndex: response.nextPageIndex,
    );
  }

  Future<List<ArtistDetailVideo>> fetchVideos(
    ArtistDetailRequest request,
  ) async {
    final list = await _fetchAllPages(
      (pageIndex) => fetchVideosPage(request, pageIndex: pageIndex),
    );
    return list;
  }

  Future<ArtistDetailPageChunk<ArtistDetailVideo>> fetchVideosPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    final response = await _fetchPage(
      path: '/v1/artist/mvs',
      request: request,
      pageSize: 200,
      pageIndex: pageIndex,
    );
    final list = response.items;
    final items = list
        .map((item) {
          final video = _asMap(item);
          final id = '${video['id'] ?? ''}'.trim();
          final name = '${video['name'] ?? ''}'.trim();
          if (id.isEmpty || name.isEmpty) {
            throw AppException(
              NetworkFailure('Invalid video item in artist videos payload.'),
            );
          }
          return ArtistDetailVideo(
            platform: _platformOf(video, request.platform),
            links: _links(video['links']),
            id: id,
            name: name,
            cover: _cover(video),
            type: _toInt(video['type']),
            playCount: _count(video, const <String>[
              'play_count',
              'playCount',
              'watch_count',
            ]),
            creator: _firstText(video, const <String>['creator']),
            duration: _toInt(video['duration']),
            description: _firstText(video, const <String>['description']),
          );
        })
        .toList(growable: false);
    return ArtistDetailPageChunk<ArtistDetailVideo>(
      items: items,
      hasMore: response.hasMore,
      nextPageIndex: response.nextPageIndex,
    );
  }

  List<LinkInfo> _links(dynamic value) {
    if (value is! List) {
      return const <LinkInfo>[];
    }
    return value
        .map((item) {
          final map = _asMap(item);
          return LinkInfo.fromMap(map);
        })
        .where((item) => item.quality > 0 || item.url.isNotEmpty)
        .toList(growable: false);
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
            return SongInfoArtistInfo(id: '', name: '$item'.trim());
          })
          .where((item) => item.name.isNotEmpty)
          .toList(growable: false);
    }
    final text = _firstText(
      <String, dynamic>{'value': value},
      const <String>['value'],
    );
    if (text.isEmpty) {
      return const <SongInfoArtistInfo>[];
    }
    return <SongInfoArtistInfo>[SongInfoArtistInfo(id: '', name: text)];
  }

  bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    final parsed = '${value ?? ''}'.trim().toLowerCase();
    return parsed == 'true' || parsed == '1';
  }

  String _title(Map<String, dynamic> raw, String fallback) {
    final value = '${raw['name'] ?? ''}'.trim();
    if (value.isNotEmpty) {
      return value;
    }
    return fallback;
  }

  String _subtitle(Map<String, dynamic> raw) {
    final alias = '${raw['alias'] ?? ''}'.trim();
    if (alias.isNotEmpty) {
      return alias;
    }
    return '';
  }

  String _cover(Map<String, dynamic> raw) {
    const keys = <String>['cover', 'pic', 'imgurl', 'image', 'thumb'];
    for (final key in keys) {
      final value = '${raw[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _description(Map<String, dynamic> raw) {
    return '${raw['description'] ?? ''}'.trim();
  }

  String _count(Map<String, dynamic> raw, List<String> keys) {
    final value = _firstText(raw, keys);
    if (value.isEmpty) {
      return '0';
    }
    return value;
  }

  List<ArtistDetailSong> _songs(Map<String, dynamic> raw, String platform) {
    final list = _resolveSongList(raw);
    if (list is! List) {
      return const <ArtistDetailSong>[];
    }
    return list
        .map((item) {
          final song = _asMap(item);
          final id = '${song['id'] ?? ''}'.trim();
          final name = '${song['name'] ?? ''}'.trim();
          if (id.isEmpty || name.isEmpty) {
            throw AppException(
              NetworkFailure('Invalid song item in artist detail payload.'),
            );
          }
          return SongInfo.fromMap(song, fallbackPlatform: platform);
        })
        .toList(growable: false);
  }

  dynamic _resolveSongList(Map<String, dynamic> raw) {
    const directKeys = <String>['songs', 'tracks', 'song_list', 'songlist'];
    for (final key in directKeys) {
      final value = raw[key];
      if (value is List) {
        return value;
      }
    }

    const nestedKeys = <String>['artist', 'data', 'detail'];
    for (final parentKey in nestedKeys) {
      final parent = raw[parentKey];
      if (parent is! Map) {
        continue;
      }
      final mapped = _asMap(parent);
      for (final childKey in directKeys) {
        final value = mapped[childKey];
        if (value is List) {
          return value;
        }
      }
    }
    return null;
  }

  String _firstText(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = '${raw[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _platformOf(Map<String, dynamic> raw, String fallback) {
    final platform = _firstText(raw, const <String>['platform']);
    if (platform.isNotEmpty) {
      return platform;
    }
    return fallback;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  Future<List<T>> _fetchAllPages<T>(
    Future<ArtistDetailPageChunk<T>> Function(int pageIndex) loader,
  ) async {
    final result = <T>[];
    var pageIndex = 1;
    var hasMore = true;
    var guard = 0;
    while (hasMore && guard < 20) {
      guard += 1;
      final chunk = await loader(pageIndex);
      result.addAll(chunk.items);
      hasMore = chunk.hasMore;
      pageIndex = chunk.nextPageIndex;
    }
    return result;
  }

  Future<_ArtistPagedRawResponse> _fetchPage({
    required String path,
    required ArtistDetailRequest request,
    required int pageSize,
    required int pageIndex,
  }) async {
    final safePageIndex = pageIndex <= 0 ? 1 : pageIndex;
    final response = await _dio.get(
      path,
      queryParameters: <String, dynamic>{
        'id': request.id,
        'platform': request.platform,
        'page_index': safePageIndex,
        'page_size': pageSize,
      },
    );
    final raw = _asMap(response.data);
    final list = raw['list'];
    return _ArtistPagedRawResponse(
      items: list is List ? list : const <dynamic>[],
      hasMore: _readHasMore(raw),
      nextPageIndex: safePageIndex + 1,
    );
  }

  bool _readHasMore(Map<String, dynamic> raw) {
    final value = raw['has_more'];
    if (value is bool) {
      return value;
    }
    final parsed = '${value ?? ''}'.trim().toLowerCase();
    return parsed == 'true' || parsed == '1';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    throw AppException(
      NetworkFailure('Invalid payload type: ${value.runtimeType}'),
    );
  }
}

class _ArtistPagedRawResponse {
  const _ArtistPagedRawResponse({
    required this.items,
    required this.hasMore,
    required this.nextPageIndex,
  });

  final List<dynamic> items;
  final bool hasMore;
  final int nextPageIndex;
}
