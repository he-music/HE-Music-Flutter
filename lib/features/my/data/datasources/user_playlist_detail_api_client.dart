import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/response_parsers.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../playlist/domain/entities/playlist_detail_song.dart';
import '../../../playlist/domain/entities/playlist_detail_songs_page_result.dart';
import '../../domain/entities/user_playlist_detail_request.dart';

class UserPlaylistDetailApiClient {
  const UserPlaylistDetailApiClient(this._dio);

  final Dio _dio;

  Future<PlaylistInfo> fetchInfo(UserPlaylistDetailRequest request) async {
    final response = await _dio.get(
      '/v1/user/playlist',
      queryParameters: <String, dynamic>{'id': request.id},
    );
    final raw = _asMap(response.data);
    return PlaylistInfo(
      name: _title(raw, request.title),
      id: request.id,
      cover: _cover(raw),
      creator: _subtitle(raw),
      songCount: _songCount(raw),
      playCount: _playCount(raw),
      songs: const <PlaylistDetailSong>[],
      platform: 'user',
      description: _description(raw),
      isDefault: _isDefault(raw['is_default']),
    );
  }

  Future<void> updatePlaylist({
    required String id,
    required String name,
    required String cover,
    required String description,
  }) async {
    await _dio.put(
      '/v1/user/playlist',
      data: <String, dynamic>{
        'id': id,
        'name': name,
        'cover': cover,
        'description': description,
      },
    );
  }

  Future<void> deletePlaylist(String id) async {
    await _dio.delete('/v1/user/playlist', data: <String, dynamic>{'id': id});
  }

  Future<PlaylistDetailSongsPageResult> fetchSongs(
    UserPlaylistDetailRequest request, {
    int pageIndex = 1,
    int pageSize = playlistDetailSongsPageSize,
  }) async {
    final safePageIndex = pageIndex <= 0 ? 1 : pageIndex;
    final safePageSize = pageSize <= 0 || pageSize > playlistDetailSongsPageSize
        ? playlistDetailSongsPageSize
        : pageSize;
    final response = await _dio.get(
      '/v1/user/playlist/songs',
      queryParameters: <String, dynamic>{
        'id': request.id,
        'page_index': safePageIndex,
        'page_size': safePageSize,
      },
    );
    final raw = _asMap(response.data);
    final list = raw['list'];
    final songs = list is List
        ? list
              .map((item) {
                final song = _asMap(item);
                final songId = '${song['id'] ?? ''}'.trim();
                final name = '${song['name'] ?? ''}'.trim();
                if (songId.isEmpty || name.isEmpty) {
                  throw AppException(
                    NetworkFailure(
                      'Invalid song item in user playlist payload.',
                    ),
                  );
                }
                return SongInfo.fromMap(
                  song,
                  fallbackPlatform: _platform(song),
                );
              })
              .toList(growable: false)
        : const <PlaylistDetailSong>[];
    return PlaylistDetailSongsPageResult(
      songs: songs,
      pageIndex: _readPositiveInt(raw['page_index'], fallback: safePageIndex),
      pageSize: _readPositiveInt(
        raw['page_size'],
        fallback: safePageSize,
        max: playlistDetailSongsPageSize,
      ),
      totalCount: _readNonNegativeInt(
        raw['total_count'],
        fallback: songs.length,
      ),
      hasMore: parseResponseBool(raw['has_more'], fallback: false),
    );
  }

  String _title(Map<String, dynamic> raw, String fallback) {
    final value = '${raw['name'] ?? ''}'.trim();
    return value.isEmpty ? fallback : value;
  }

  String _subtitle(Map<String, dynamic> raw) {
    final custom = '${raw['creator'] ?? ''}'.trim();
    if (custom.isNotEmpty) {
      return custom;
    }
    return '-';
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

  String _playCount(Map<String, dynamic> raw) {
    const keys = <String>['play_count', 'playCount'];
    for (final key in keys) {
      final value = '${raw[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _songCount(Map<String, dynamic> raw) {
    const keys = <String>['song_count', 'songCount', 'trackCount'];
    for (final key in keys) {
      final value = '${raw[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _platform(Map<String, dynamic> raw) {
    final value = '${raw['platform'] ?? ''}'.trim();
    return value.isEmpty ? 'unknown' : value;
  }

  bool _isDefault(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value.toInt() == 1;
    }
    final text = '$value'.trim().toLowerCase();
    return text == '1' || text == 'true';
  }

  Map<String, dynamic> _asMap(dynamic value) => parseResponseMap(value);

  int _readPositiveInt(dynamic value, {required int fallback, int? max}) {
    final parsed = value is int ? value : int.tryParse('$value');
    if (parsed == null || parsed <= 0 || (max != null && parsed > max)) {
      return fallback;
    }
    return parsed;
  }

  int _readNonNegativeInt(dynamic value, {required int fallback}) {
    final parsed = value is int ? value : int.tryParse('$value');
    return parsed == null || parsed < 0 ? fallback : parsed;
  }
}
