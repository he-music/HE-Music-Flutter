import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/playlist_detail_request.dart';
import '../../domain/entities/playlist_detail_song.dart';
import '../../domain/entities/playlist_detail_songs_page_result.dart';

class PlaylistDetailApiClient {
  const PlaylistDetailApiClient(this._dio);

  final Dio _dio;

  Future<PlaylistInfo> fetchInfo(PlaylistDetailRequest request) async {
    final response = await _dio.get(
      '/v1/playlist',
      queryParameters: <String, dynamic>{
        'id': request.id,
        'platform': request.platform,
      },
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
      platform: request.platform,
      description: _description(raw),
    );
  }

  Future<PlaylistDetailSongsPageResult> fetchSongs(
    PlaylistDetailRequest request, {
    int pageIndex = 1,
    int pageSize = playlistDetailSongsPageSize,
  }) async {
    final safePageIndex = pageIndex <= 0 ? 1 : pageIndex;
    final safePageSize = pageSize <= 0 || pageSize > playlistDetailSongsPageSize
        ? playlistDetailSongsPageSize
        : pageSize;
    final response = await _dio.get(
      '/v1/playlist/songs',
      queryParameters: <String, dynamic>{
        'id': request.id,
        'platform': request.platform,
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
                final id = '${song['id'] ?? ''}'.trim();
                final name = '${song['name'] ?? ''}'.trim();
                if (id.isEmpty || name.isEmpty) {
                  throw AppException(
                    NetworkFailure(
                      'Invalid song item in playlist detail payload.',
                    ),
                  );
                }
                return SongInfo.fromMap(
                  song,
                  fallbackPlatform: request.platform,
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
      hasMore: _readBool(raw['has_more'], fallback: false),
    );
  }

  String _title(Map<String, dynamic> raw, String fallback) {
    final value = '${raw['name'] ?? ''}'.trim();
    if (value.isNotEmpty) {
      return value;
    }
    return fallback;
  }

  String _subtitle(Map<String, dynamic> raw) {
    final creator = '${raw['creator'] ?? ''}'.trim();
    if (creator.isNotEmpty) {
      return creator;
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

  bool _readBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = '$value'.trim().toLowerCase();
    if (text == 'true' || text == '1') {
      return true;
    }
    if (text == 'false' || text == '0') {
      return false;
    }
    return fallback;
  }
}
