import 'package:dio/dio.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../shared/models/he_music_models.dart';
import '../../../shared/domain/entities/new_release_page_result.dart';
import '../../../shared/domain/entities/new_release_tab.dart';

class NewAlbumApiClient {
  const NewAlbumApiClient(this._dio);

  final Dio _dio;

  Future<List<NewReleaseTab>> fetchTabs({required String platform}) async {
    final response = await _dio.get(
      '/v1/album/new/tabs',
      queryParameters: <String, dynamic>{'platform': platform},
    );
    final payload = _asMap(response.data);
    final listRaw = payload['list'];
    if (listRaw is! List) {
      throw const AppException(
        NetworkFailure('Invalid /v1/album/new/tabs response: missing list'),
      );
    }
    return listRaw
        .map(
          (item) =>
              NewReleaseTab.fromMap(_asMap(item), fallbackPlatform: platform),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<NewReleasePageResult<AlbumInfo>> fetchAlbums({
    required String platform,
    required String tabId,
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    final safePageIndex = pageIndex <= 0 ? 1 : pageIndex;
    final safePageSize = pageSize <= 0 ? 30 : pageSize;
    final response = await _dio.get(
      '/v1/album/tab/news',
      queryParameters: <String, dynamic>{
        'platform': platform,
        'tab_id': tabId,
        'page_index': safePageIndex,
        'page_size': safePageSize,
      },
    );
    final payload = _asMap(response.data);
    final listRaw = payload['list'];
    if (listRaw is! List) {
      throw const AppException(
        NetworkFailure('Invalid /v1/album/tab/news response: missing list'),
      );
    }
    final list = listRaw
        .map(
          (item) => AlbumInfo.fromMap(_asMap(item), fallbackPlatform: platform),
        )
        .toList(growable: false);
    return NewReleasePageResult<AlbumInfo>(
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
