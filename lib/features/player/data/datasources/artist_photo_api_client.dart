import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';

/// 歌手写真 API 客户端，调用 GET /v1/artist/photos 接口。
class ArtistPhotoApiClient {
  const ArtistPhotoApiClient(this._dio);

  final Dio _dio;

  /// 获取歌手写真 URL 列表。
  ///
  /// [platform] 平台标识。
  /// [ids] 歌手 ID 列表，可选。
  /// [names] 歌手名称列表，至少传一个。
  /// [isPortrait] 是否只返回竖版写真。
  Future<List<String>> listPhotos({
    required String platform,
    List<String> ids = const <String>[],
    List<String> names = const <String>[],
    bool isPortrait = false,
  }) async {
    final response = await _dio.get(
      '/v1/artist/photos',
      queryParameters: <String, dynamic>{
        'platform': platform,
        if (ids.isNotEmpty) 'ids': ids,
        if (names.isNotEmpty) 'names': names,
        'is_portrait': isPortrait,
      },
    );
    final raw = _asMap(response.data);
    final urlsRaw = raw['urls'];
    if (urlsRaw is List) {
      return urlsRaw
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    throw const AppException(
      NetworkFailure('Invalid artist photo response payload.'),
    );
  }
}
