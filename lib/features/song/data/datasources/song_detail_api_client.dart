import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/song_detail_content.dart';
import '../../domain/entities/song_detail_relations.dart';
import '../../domain/entities/song_detail_request.dart';

class SongDetailApiClient {
  const SongDetailApiClient(this._dio);

  final Dio _dio;

  Future<SongDetailContent> fetchDetail(SongDetailRequest request) async {
    final response = await _dio.get(
      '/v1/song/detail',
      queryParameters: <String, dynamic>{
        'id': request.id,
        'platform': request.platform,
      },
    );
    final raw = _asMap(response.data);
    final songMap = _resolveSongMap(raw);
    final song = SongInfo.fromMap(songMap, fallbackPlatform: request.platform);
    if (song.id.trim().isEmpty || song.title.trim().isEmpty) {
      throw AppException(
        NetworkFailure('Invalid song detail payload: missing song identity.'),
      );
    }
    final metadata = _asNullableMap(raw['metadata']) ?? <String, dynamic>{};
    return SongDetailContent(
      song: song,
      publishTime: _firstString(metadata, const <String>[
        'publish_time',
        'publishTime',
      ]),
      language: _firstString(metadata, const <String>['language']),
    );
  }

  Future<SongDetailRelations> fetchRelations(SongDetailRequest request) async {
    final response = await _dio.get(
      '/v1/song/relations',
      queryParameters: <String, dynamic>{
        'id': request.id,
        'platform': request.platform,
      },
    );
    final raw = _asMap(response.data);
    return SongDetailRelations(
      similarSongs: _songs(raw['similar_songs'], request.platform),
      otherVersionSongs: _songs(raw['other_version_songs'], request.platform),
      relatedPlaylists: _playlists(raw['related_playlists'], request.platform),
      relatedMvs: _mvs(raw['related_mvs'], request.platform),
    );
  }

  Map<String, dynamic> _resolveSongMap(Map<String, dynamic> raw) {
    final songMap = _asNullableMap(raw['song']);
    if (songMap != null) {
      return songMap;
    }
    return raw;
  }

  List<SongInfo> _songs(dynamic value, String platform) {
    if (value is! List) {
      return const <SongInfo>[];
    }
    return value
        .map(
          (item) => SongInfo.fromMap(_asMap(item), fallbackPlatform: platform),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<PlaylistInfo> _playlists(dynamic value, String platform) {
    if (value is! List) {
      return const <PlaylistInfo>[];
    }
    return value
        .map(
          (item) =>
              PlaylistInfo.fromMap(_asMap(item), fallbackPlatform: platform),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<MvInfo> _mvs(dynamic value, String platform) {
    if (value is! List) {
      return const <MvInfo>[];
    }
    return value
        .map((item) => MvInfo.fromMap(_asMap(item), fallbackPlatform: platform))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  String _firstString(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = '${raw[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  Map<String, dynamic>? _asNullableMap(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    final map = _asNullableMap(value);
    if (map != null) {
      return map;
    }
    throw AppException(
      NetworkFailure('Invalid payload type: ${value.runtimeType}'),
    );
  }
}
