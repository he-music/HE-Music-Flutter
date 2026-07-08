import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';

class RadioApiClient {
  const RadioApiClient(this._dio);

  final Dio _dio;

  Future<List<RadioGroupInfo>> fetchGroups({required String platform}) async {
    final response = await _dio.get(
      '/v1/radios',
      queryParameters: <String, dynamic>{'platform': platform},
    );
    final payload = _asMap(response.data);
    final groupsRaw = payload['groups'];
    if (groupsRaw is! List) {
      throw const AppException(
        NetworkFailure('Invalid /v1/radios response: missing groups'),
      );
    }
    return groupsRaw
        .map(
          (item) =>
              RadioGroupInfo.fromMap(_asMap(item), fallbackPlatform: platform),
        )
        .toList(growable: false);
  }

  Future<List<SongInfo>> fetchSongs({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 50,
  }) async {
    final safePageIndex = pageIndex <= 0 ? 1 : pageIndex;
    final safePageSize = pageSize <= 0 ? 50 : pageSize;
    final response = await _dio.get(
      '/v1/radio/songs',
      queryParameters: <String, dynamic>{
        'id': id,
        'platform': platform,
        'page_index': safePageIndex,
        'page_size': safePageSize,
      },
    );
    final payload = _asMap(response.data);
    final songsRaw = payload['list'];
    if (songsRaw is! List) {
      throw const AppException(
        NetworkFailure('Invalid /v1/radio/songs response: missing songs'),
      );
    }
    return songsRaw
        .map(
          (item) => SongInfo.fromMap(_asMap(item), fallbackPlatform: platform),
        )
        .toList(growable: false);
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
