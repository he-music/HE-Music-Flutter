import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../domain/entities/home_discover_item.dart';
import '../../domain/entities/home_discover_section.dart';
import '../../domain/entities/home_platform.dart';

class HomeDiscoverApiClient {
  const HomeDiscoverApiClient(this._dio);

  final Dio _dio;

  Future<List<HomePlatform>> fetchPlatforms() async {
    final response = await _dio.get('/v1/platforms');
    final payload = _asMap(response.data);
    final list = payload['list'];
    if (list is! List) {
      throw const AppException(
        NetworkFailure('Invalid /v1/platforms response: missing list'),
      );
    }
    return list
        .map((item) => HomePlatform.fromMap(_asMap(item)))
        .toList(growable: false);
  }

  Future<List<HomeDiscoverSection>> fetchDiscoverSections(
    String platformId,
  ) async {
    final response = await _dio.get(
      '/v1/page/discover',
      queryParameters: <String, dynamic>{'platform': platformId},
    );
    final payload = _asMap(response.data);
    return <HomeDiscoverSection>[
      HomeDiscoverSection(
        key: 'new-song',
        titleKey: 'home.section.new_song',
        type: HomeDiscoverItemType.song,
        songs: _parseList(
          payload: payload,
          field: 'new_songs',
          parser: (item) =>
              SongInfo.fromMap(item, fallbackPlatform: platformId),
        ),
      ),
      HomeDiscoverSection(
        key: 'new-album',
        titleKey: 'home.section.new_album',
        type: HomeDiscoverItemType.album,
        albums: _parseList(
          payload: payload,
          field: 'new_albums',
          parser: (item) =>
              AlbumInfo.fromMap(item, fallbackPlatform: platformId),
        ),
      ),
      HomeDiscoverSection(
        key: 'featured-playlist',
        titleKey: 'home.section.playlist',
        type: HomeDiscoverItemType.playlist,
        playlists: _parseList(
          payload: payload,
          field: 'featured_playlists',
          parser: (item) =>
              PlaylistInfo.fromMap(item, fallbackPlatform: platformId),
        ),
      ),
      HomeDiscoverSection(
        key: 'featured-mv',
        titleKey: 'home.section.video',
        type: HomeDiscoverItemType.video,
        videos: _parseList(
          payload: payload,
          field: 'featured_mvs',
          parser: (item) => MvInfo.fromMap(item, fallbackPlatform: platformId),
        ),
      ),
    ];
  }

  List<T> _parseList<T>({
    required Map<String, dynamic> payload,
    required String field,
    required T Function(Map<String, dynamic> item) parser,
  }) {
    final list = payload[field];
    if (list is! List) {
      throw AppException(
        NetworkFailure('Invalid /v1/page/discover response: missing $field'),
      );
    }
    return list.map((item) => parser(_asMap(item))).toList(growable: false);
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
