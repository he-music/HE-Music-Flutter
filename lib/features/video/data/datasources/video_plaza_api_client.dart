import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/video_plaza_page_result.dart';

class VideoPlazaApiClient {
  const VideoPlazaApiClient(this._dio);

  final Dio _dio;

  Future<List<FilterInfo>> fetchFilters({required String platform}) async {
    final response = await _dio.get(
      '/v1/mv/filters',
      queryParameters: <String, dynamic>{'platform': platform},
    );
    final payload = _asMap(response.data);
    final filtersRaw = payload['filters'];
    if (filtersRaw is! List) {
      throw const AppException(
        NetworkFailure('Invalid /v1/mv/filters response: missing filters'),
      );
    }
    return filtersRaw
        .map(
          (item) =>
              FilterInfo.fromMap(_asMap(item), fallbackPlatform: platform),
        )
        .toList(growable: false);
  }

  Future<VideoPlazaPageResult> fetchVideos({
    required String platform,
    required Map<String, String> filters,
    int pageIndex = 1,
    int pageSize = 50,
  }) async {
    final safePageIndex = pageIndex <= 0 ? 1 : pageIndex;
    final safePageSize = pageSize <= 0 ? 50 : pageSize;
    final response = await _dio.get(
      '/v1/mv/filter/mvs',
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
        NetworkFailure('Invalid /v1/mv/filter/mvs response: missing list'),
      );
    }
    final list = listRaw
        .map((item) => MvInfo.fromMap(_asMap(item), fallbackPlatform: platform))
        .toList(growable: false);
    return VideoPlazaPageResult(
      list: list,
      hasMore: _readBool(
        payload['has_more'],
        fallback: list.length >= safePageSize,
      ),
    );
  }

  /// 加载推荐 MV feed 列表，用于详情页上下滑动浏览。
  Future<VideoPlazaPageResult> fetchMvFeed({
    required String id,
    required String platform,
    int pageIndex = 1,
  }) async {
    final safePageIndex = pageIndex <= 0 ? 1 : pageIndex;
    final response = await _dio.get(
      '/v1/mv/feeds',
      queryParameters: <String, dynamic>{
        'id': id,
        'platform': platform,
        'page_index': safePageIndex,
      },
    );
    final payload = _asMap(response.data);
    final listRaw = payload['list'];
    if (listRaw is! List) {
      throw const AppException(
        NetworkFailure('Invalid /v1/mv/feeds response: missing list'),
      );
    }
    final list = listRaw
        .map((item) => MvInfo.fromMap(_asMap(item), fallbackPlatform: platform))
        .toList(growable: false);
    return VideoPlazaPageResult(
      list: list,
      hasMore: _readBool(payload['has_more'], fallback: list.isNotEmpty),
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
