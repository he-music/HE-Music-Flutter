import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/album_detail_content.dart';
import '../../domain/entities/album_detail_request.dart';
import '../../domain/entities/album_detail_song.dart';

class AlbumDetailApiClient {
  const AlbumDetailApiClient(this._dio);

  final Dio _dio;

  Future<AlbumDetailContent> fetchDetail(AlbumDetailRequest request) async {
    final response = await _dio.get(
      '/v1/album',
      queryParameters: <String, dynamic>{
        'id': request.id,
        'platform': request.platform,
      },
    );
    final raw = _asMap(response.data);
    final songs = _songs(raw, request.platform);
    return AlbumDetailContent(
      info: AlbumInfo(
        name: _title(raw, request.title),
        id: request.id,
        cover: _cover(raw),
        artists: _artists(raw['artists']),
        songCount: _songCount(raw, songs.length),
        publishTime: _publishTime(raw),
        songs: songs,
        description: _description(raw),
        platform: request.platform,
        language: _string(raw['language']),
        genre: _string(raw['genre']),
        type: _int(raw['type']),
        isFinished: _bool(raw['is_finished']),
        playCount: _string(raw['play_count']),
      ),
      songs: songs,
    );
  }

  String _title(Map<String, dynamic> raw, String fallback) {
    final value = '${raw['name'] ?? ''}'.trim();
    if (value.isNotEmpty) {
      return value;
    }
    return fallback;
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

  String _songCount(Map<String, dynamic> raw, int fallback) {
    const keys = <String>['song_count', 'songCount', 'trackCount'];
    for (final key in keys) {
      final value = _string(raw[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '$fallback';
  }

  String _publishTime(Map<String, dynamic> raw) {
    const keys = <String>['publish_time', 'publishTime', 'createTime'];
    for (final key in keys) {
      final value = '${raw[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  List<AlbumDetailSong> _songs(Map<String, dynamic> raw, String platform) {
    final list = _resolveSongList(raw);
    if (list is! List) {
      return const <AlbumDetailSong>[];
    }
    return list
        .map((item) {
          final song = _asMap(item);
          final id = '${song['id'] ?? ''}'.trim();
          final name = '${song['name'] ?? ''}'.trim();
          if (id.isEmpty || name.isEmpty) {
            throw AppException(
              NetworkFailure('Invalid song item in album detail payload.'),
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

    const nestedKeys = <String>['data', 'detail', 'album'];
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
    final text = _string(value);
    if (text.isEmpty) {
      return const <SongInfoArtistInfo>[];
    }
    return <SongInfoArtistInfo>[SongInfoArtistInfo(id: '', name: text)];
  }

  String _string(dynamic value) => '${value ?? ''}'.trim();

  int _int(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  bool _bool(dynamic value) {
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
