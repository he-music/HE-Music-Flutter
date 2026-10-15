import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/song_detail_content.dart';
import '../../domain/entities/song_detail_field.dart';
import '../../domain/entities/song_detail_section.dart';
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
    final songMap = _asMap(raw['song']);
    final song = SongInfo.fromMap(songMap, fallbackPlatform: request.platform);
    if (song.id.trim().isEmpty || song.title.trim().isEmpty) {
      throw AppException(
        NetworkFailure('Invalid song detail payload: missing song identity.'),
      );
    }
    return SongDetailContent(
      song: song,
      fields: _parseList(raw['fields'], SongDetailField.fromMap),
      sections: _parseList(
        raw['sections'],
        (item) =>
            SongDetailSection.fromMap(item, fallbackPlatform: request.platform),
      ),
    );
  }

  List<T> _parseList<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
    if (raw is! List) return <T>[];
    return List<T>.unmodifiable(
      raw.whereType<Map>().map(
        (item) => parse(Map<String, dynamic>.from(item)),
      ),
    );
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
