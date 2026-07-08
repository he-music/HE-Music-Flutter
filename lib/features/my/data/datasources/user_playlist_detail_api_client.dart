import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../playlist/domain/entities/playlist_detail_content.dart';
import '../../../playlist/domain/entities/playlist_detail_song.dart';
import '../../domain/entities/user_playlist_detail_request.dart';

class UserPlaylistDetailApiClient {
  const UserPlaylistDetailApiClient(this._dio);

  final Dio _dio;

  Future<PlaylistDetailContent> fetchDetail(
    UserPlaylistDetailRequest request,
  ) async {
    final response = await _dio.get(
      '/v1/user/playlist',
      queryParameters: <String, dynamic>{'id': request.id},
    );
    final raw = _asMap(response.data);
    final songs = await _fetchPlaylistSongs(request.id);
    return PlaylistDetailContent(
      info: PlaylistInfo(
        name: _title(raw, request.title),
        id: request.id,
        cover: _cover(raw),
        creator: _subtitle(raw),
        songCount: _songCount(raw, songs.length),
        playCount: _playCount(raw),
        songs: songs,
        platform: 'user',
        description: _description(raw),
        isDefault: _isDefault(raw['is_default']),
      ),
      songs: songs,
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

  Future<List<PlaylistDetailSong>> _fetchPlaylistSongs(String id) async {
    final response = await _dio.get(
      '/v1/user/playlist/songs',
      queryParameters: <String, dynamic>{
        'id': id,
        'page_index': 1,
        'page_size': 1000,
      },
    );
    final raw = _asMap(response.data);
    final list = raw['list'];
    if (list is! List) {
      return const <PlaylistDetailSong>[];
    }
    return list
        .map((item) {
          final song = _asMap(item);
          final songId = '${song['id'] ?? ''}'.trim();
          final name = '${song['name'] ?? ''}'.trim();
          if (songId.isEmpty || name.isEmpty) {
            throw AppException(
              NetworkFailure('Invalid song item in user playlist payload.'),
            );
          }
          return SongInfo.fromMap(song, fallbackPlatform: _platform(song));
        })
        .toList(growable: false);
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

  String _songCount(Map<String, dynamic> raw, int fallbackCount) {
    const keys = <String>['song_count', 'songCount', 'trackCount'];
    for (final key in keys) {
      final value = '${raw[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '$fallbackCount';
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
