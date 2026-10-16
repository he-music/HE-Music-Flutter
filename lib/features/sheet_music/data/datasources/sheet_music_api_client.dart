import 'package:dio/dio.dart';

import '../../../../core/network/response_parsers.dart';
import '../../domain/entities/sheet_music_info.dart';
import '../../domain/entities/sheet_music_not_implemented_exception.dart';

class SheetMusicApiClient {
  const SheetMusicApiClient(this._dio);

  final Dio _dio;

  Future<List<SheetMusicInfo>> fetchList({
    required String platform,
    required String songId,
  }) async {
    final raw = await _get('/v1/song/sheet-music', {
      'platform': platform,
      'song_id': songId,
    });
    final list = raw['list'];
    if (list is! List) return const [];
    return List.unmodifiable(
      list.whereType<Map>().map(
        (item) => SheetMusicInfo.fromMap(parseResponseMap(item)),
      ),
    );
  }

  Future<SheetMusicInfo> fetchDetail({
    required String platform,
    required String id,
    required String songId,
  }) async {
    final raw = await _get('/v1/sheet-music', {
      'platform': platform,
      'id': id,
      'song_id': songId,
    });
    // 详情响应本身就是 SheetMusicInfo，不额外读取 info 字段。
    return SheetMusicInfo.fromMap(raw);
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
        // 页面提供错误和重试，避免全局 toast 同时显示后端的占位错误。
        options: Options(extra: {'silentErrorMessage': true}),
      );
      final raw = parseResponseMap(response.data);
      if (_isNotImplemented(raw)) {
        throw const SheetMusicNotImplementedException();
      }
      return raw;
    } on DioException catch (error) {
      if (error.response?.statusCode == 501 ||
          _isNotImplemented(error.response?.data)) {
        throw const SheetMusicNotImplementedException();
      }
      rethrow;
    }
  }

  bool _isNotImplemented(dynamic raw) {
    if (raw is! Map) return false;
    for (final key in const ['reason', 'code', 'error', 'message']) {
      final value = raw[key];
      if (value is String &&
          value.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase() ==
              'notimplemented') {
        return true;
      }
    }
    return _isNotImplemented(raw['data']);
  }
}
