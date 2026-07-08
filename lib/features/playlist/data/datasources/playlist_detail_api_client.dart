import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/playlist_detail_content.dart';
import '../../domain/entities/playlist_detail_request.dart';
import '../../domain/entities/playlist_detail_song.dart';

class PlaylistDetailApiClient {
  const PlaylistDetailApiClient(this._dio);

  final Dio _dio;

  Future<PlaylistDetailContent> fetchDetail(
    PlaylistDetailRequest request,
  ) async {
    final response = await _dio.get(
      '/v1/playlist',
      queryParameters: <String, dynamic>{
        'id': request.id,
        'platform': request.platform,
      },
    );
    final raw = _asMap(response.data);
    final songs = await _fetchPlaylistSongs(
      id: request.id,
      platform: request.platform,
    );
    return PlaylistDetailContent(
      info: PlaylistInfo(
        name: _title(raw, request.title),
        id: request.id,
        cover: _cover(raw),
        creator: _subtitle(raw),
        songCount: _songCount(raw),
        playCount: _playCount(raw),
        songs: songs,
        platform: request.platform,
        description: _description(raw),
      ),
      songs: songs,
    );
  }

  Future<List<PlaylistDetailSong>> _fetchPlaylistSongs({
    required String id,
    required String platform,
  }) async {
    final response = await _dio.get(
      '/v1/playlist/songs',
      queryParameters: <String, dynamic>{
        'id': id,
        'platform': platform,
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
          final id = '${song['id'] ?? ''}'.trim();
          final name = '${song['name'] ?? ''}'.trim();
          if (id.isEmpty || name.isEmpty) {
            throw AppException(
              NetworkFailure('Invalid song item in playlist detail payload.'),
            );
          }
          return SongInfo.fromMap(song, fallbackPlatform: platform);
        })
        .toList(growable: false);
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
}
