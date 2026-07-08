import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/artist_plaza_page_result.dart';

class ArtistPlazaApiClient {
  const ArtistPlazaApiClient(this._dio);

  final Dio _dio;

  Future<List<FilterInfo>> fetchFilters({required String platform}) async {
    final response = await _dio.get(
      '/v1/artist/filters',
      queryParameters: <String, dynamic>{'platform': platform},
    );
    final payload = _asMap(response.data);
    final filtersRaw = payload['filters'];
    if (filtersRaw is! List) {
      throw const AppException(
        NetworkFailure('Invalid /v1/artist/filters response: missing filters'),
      );
    }
    return filtersRaw
        .map(
          (item) =>
              FilterInfo.fromMap(_asMap(item), fallbackPlatform: platform),
        )
        .toList(growable: false);
  }

  Future<ArtistPlazaPageResult> fetchArtists({
    required String platform,
    required Map<String, String> filters,
    int pageIndex = 1,
    int pageSize = 50,
  }) async {
    final safePageIndex = pageIndex <= 0 ? 1 : pageIndex;
    final safePageSize = pageSize <= 0 ? 50 : pageSize;
    final response = await _dio.get(
      '/v1/artist/filter/artists',
      queryParameters: <String, dynamic>{
        'platform': platform,
        'page_index': safePageIndex,
        'page_size': safePageSize,
        'filters': filters,
      },
    );
    final payload = _asMap(response.data);
    final listRaw = payload['list'];
    if (listRaw is! List) {
      throw const AppException(
        NetworkFailure(
          'Invalid /v1/artist/filter/artists response: missing list',
        ),
      );
    }
    final list = listRaw
        .map(
          (item) =>
              ArtistInfo.fromMap(_asMap(item), fallbackPlatform: platform),
        )
        .toList(growable: false);
    return ArtistPlazaPageResult(
      list: list,
      hasMore: _readBool(
        payload['has_more'],
        fallback: list.length >= safePageSize,
      ),
    );
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
