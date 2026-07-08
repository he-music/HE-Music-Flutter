import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/video_detail_content.dart';
import '../../domain/entities/video_detail_link.dart';
import '../../domain/entities/video_detail_request.dart';

class VideoDetailApiClient {
  const VideoDetailApiClient(this._dio);

  final Dio _dio;

  Future<VideoDetailContent> fetchDetail(VideoDetailRequest request) async {
    final response = await _dio.get(
      '/v1/mv',
      queryParameters: <String, dynamic>{
        'id': request.id,
        'platform': request.platform,
      },
    );
    final raw = _asMap(response.data);
    final links = _links(raw['links']);
    return VideoDetailContent(
      info: MvInfo(
        platform: request.platform,
        links: links,
        id: request.id,
        name: _title(raw, request.title),
        cover: _cover(raw),
        type: _int(raw['type']),
        playCount: _string(raw['play_count']),
        creator: _string(raw['creator']),
        duration: _int(raw['duration']),
        description: _string(raw['description']),
      ),
      links: links,
    );
  }

  List<VideoDetailLink> _links(dynamic value) {
    if (value is! List) {
      return const <VideoDetailLink>[];
    }
    return value
        .map((item) {
          final map = _asMap(item);
          return LinkInfo.fromMap(map);
        })
        .where((item) => item.quality > 0 || item.url.isNotEmpty)
        .toList(growable: false);
  }

  String _title(Map<String, dynamic> raw, String fallback) {
    final value = _string(raw['name']);
    if (value.isNotEmpty) {
      return value;
    }
    return fallback;
  }

  String _cover(Map<String, dynamic> raw) {
    const keys = <String>['cover', 'pic', 'imgurl', 'image', 'thumb'];
    for (final key in keys) {
      final value = _string(raw[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _string(dynamic value) {
    return '${value ?? ''}'.trim();
  }

  int _int(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('${value ?? ''}') ?? 0;
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
