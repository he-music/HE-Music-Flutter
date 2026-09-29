import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/response_parsers.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/playlist_category_group.dart';
import '../../domain/entities/playlist_plaza_page_result.dart';

class PlaylistPlazaApiClient {
  const PlaylistPlazaApiClient(this._dio);

  final Dio _dio;

  Future<List<PlaylistCategoryGroup>> fetchCategories({
    required String platform,
  }) async {
    final response = await _dio.get(
      '/v1/playlist/categories',
      queryParameters: <String, dynamic>{'platform': platform},
    );
    final payload = _asMap(response.data);
    final groupsRaw = payload['groups'];
    if (groupsRaw is! List) {
      throw const AppException(
        NetworkFailure(
          'Invalid /v1/playlist/categories response: missing groups',
        ),
      );
    }
    return groupsRaw
        .map(
          (item) =>
              PlaylistCategoryGroup.fromMap(_asMap(item), platform: platform),
        )
        .toList(growable: false);
  }

  Future<PlaylistPlazaPageResult> fetchCategoryPlaylists({
    required String platform,
    required String categoryId,
    int pageIndex = 1,
    int pageSize = 30,
    String? lastId,
  }) async {
    final safePageIndex = pageIndex <= 0 ? 1 : pageIndex;
    final safePageSize = pageSize <= 0 ? 30 : pageSize;
    final response = await _dio.get(
      '/v1/category/playlists',
      queryParameters: <String, dynamic>{
        'platform': platform,
        'category_id': categoryId,
        'page_index': safePageIndex,
        'page_size': safePageSize,
        if (lastId != null && lastId.trim().isNotEmpty)
          'last_id': lastId.trim(),
      },
    );
    final payload = _asMap(response.data);
    final listRaw = payload['list'];
    if (listRaw is! List) {
      throw const AppException(
        NetworkFailure('Invalid /v1/category/playlists response: missing list'),
      );
    }
    final list = listRaw
        .map(
          (item) =>
              PlaylistInfo.fromMap(_asMap(item), fallbackPlatform: platform),
        )
        .toList(growable: false);
    return PlaylistPlazaPageResult(
      list: list,
      hasMore: _readBool(
        payload['has_more'],
        fallback: list.length >= safePageSize,
      ),
      lastId: '${payload['last_id'] ?? ''}'.trim(),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) => parseResponseMap(value);

  bool _readBool(dynamic value, {required bool fallback}) =>
      parseResponseBool(value, fallback: fallback);
}
