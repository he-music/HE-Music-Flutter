import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../domain/entities/ranking_detail.dart';
import '../../domain/entities/ranking_group.dart';
import '../../domain/entities/ranking_info.dart';
import '../../domain/entities/ranking_preview_song.dart';
import '../../domain/entities/ranking_song.dart';

class RankingApiClient {
  const RankingApiClient(this._dio);

  final Dio _dio;

  Future<List<OnlinePlatform>> fetchPlatforms() async {
    final response = await _dio.get('/v1/platforms');
    final payload = _asMap(response.data);
    final list = payload['list'];
    if (list is! List) {
      throw const AppException(
        NetworkFailure('Invalid /v1/platforms response: missing list'),
      );
    }
    return list
        .map((item) => OnlinePlatform.fromMap(_asMap(item)))
        .toList(growable: false);
  }

  Future<List<RankingGroup>> fetchRankingGroups({
    required String platform,
  }) async {
    final response = await _dio.get(
      '/v1/rankings',
      queryParameters: <String, dynamic>{'platform': platform},
    );
    final payload = _asMap(response.data);
    final groupsRaw = payload['groups'];
    if (groupsRaw is! List) {
      throw const AppException(
        NetworkFailure('Invalid /v1/rankings response: missing groups'),
      );
    }
    return groupsRaw
        .map((item) => _parseGroup(_asMap(item), platform))
        .toList(growable: false);
  }

  Future<RankingDetail> fetchRankingDetail({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 100,
    String? lastId,
  }) async {
    final safePageIndex = pageIndex <= 0 ? 1 : pageIndex;
    final safePageSize = pageSize <= 0 ? 100 : pageSize;
    final response = await _dio.get(
      '/v1/ranking',
      queryParameters: <String, dynamic>{
        'id': id,
        'platform': platform,
        'page_index': safePageIndex,
        'page_size': safePageSize,
        if (lastId != null && lastId.trim().isNotEmpty)
          'last_id': lastId.trim(),
      },
    );
    final payload = _asMap(response.data);
    final info = _parseRankingInfo(payload, platform, fallbackId: id);
    final songs = _parseSongs(payload, platform);
    final hasMore = _readBool(payload, <String>['has_more', 'hasMore']);
    final last = _readString(payload, <String>['last_id', 'lastId']);
    final totalCount = _readInt(payload, <String>['total_count', 'totalCount']);
    final description = _readString(payload, <String>['description', 'desc']);
    return RankingDetail(
      info: info,
      songs: songs,
      hasMore: hasMore,
      lastId: last,
      totalCount: totalCount,
      description: description,
    );
  }

  RankingGroup _parseGroup(Map<String, dynamic> raw, String platform) {
    final name = _readString(raw, <String>['name', 'title']);
    final rankingsRaw = raw['rankings'];
    final list = rankingsRaw is List ? rankingsRaw : const <dynamic>[];
    return RankingGroup(
      name: name.isEmpty ? '榜单' : name,
      rankings: list
          .map((item) => _parseRankingInfo(_asMap(item), platform))
          .toList(growable: false),
    );
  }

  RankingInfo _parseRankingInfo(
    Map<String, dynamic> raw,
    String fallbackPlatform, {
    String? fallbackId,
  }) {
    final id = _readString(raw, <String>['id']);
    final platform = _readString(raw, <String>['platform']);
    final name = _readString(raw, <String>['name', 'title']);
    final coverUrl = _readString(raw, <String>[
      'cover',
      'pic',
      'imgurl',
      'image',
    ]);
    final songsRaw = raw['songs'];
    final songs = songsRaw is List ? songsRaw : const <dynamic>[];
    final previewSongs = songs
        .take(3)
        .map((item) {
          final song = _asMap(item);
          final songName = _readString(song, <String>['name', 'title']);
          final artist = SongInfo.fromMap(
            song,
            fallbackPlatform: fallbackPlatform,
          ).artist;
          return RankingPreviewSong(
            name: songName.isEmpty ? '-' : songName,
            artist: artist.isEmpty ? '-' : artist,
          );
        })
        .toList(growable: false);
    return RankingInfo(
      id: id.isEmpty ? (fallbackId ?? '-') : id,
      platform: platform.isEmpty ? fallbackPlatform : platform,
      name: name.isEmpty ? '-' : name,
      coverUrl: coverUrl,
      previewSongs: previewSongs,
    );
  }

  List<RankingSong> _parseSongs(
    Map<String, dynamic> raw,
    String fallbackPlatform,
  ) {
    final listRaw = raw['songs'];
    if (listRaw is! List) {
      return const <RankingSong>[];
    }
    return listRaw
        .map((item) {
          final song = _asMap(item);
          final id = _readString(song, <String>['id']);
          final name = _readString(song, <String>['name', 'title']);
          if (id.isEmpty || name.isEmpty) {
            throw const AppException(
              NetworkFailure('Invalid song item in /v1/ranking payload'),
            );
          }
          return SongInfo.fromMap(song, fallbackPlatform: fallbackPlatform);
        })
        .toList(growable: false);
  }

  String _readString(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = '${raw[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  int _readInt(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is int) {
        return value;
      }
      final parsed = int.tryParse('$value');
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }

  bool _readBool(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      final parsed = '$value'.trim().toLowerCase();
      if (parsed == 'true' || parsed == '1') {
        return true;
      }
      if (parsed == 'false' || parsed == '0') {
        return false;
      }
    }
    return false;
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
