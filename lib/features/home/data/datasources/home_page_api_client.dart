import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../ranking/domain/entities/ranking_info.dart';
import '../../domain/entities/home_page_result.dart';
import '../../domain/entities/home_page_section.dart';
import '../../domain/entities/recommend_song_list_info.dart';
import '../../domain/entities/recommend_song_list_request.dart';

class HomePageApiClient {
  const HomePageApiClient(this._dio);

  final Dio _dio;

  Future<HomePageResult> fetchRecommendPage({
    required String platformId,
    required int pageIndex,
  }) async {
    final response = await _dio.get(
      '/v1/page/recommend',
      queryParameters: <String, dynamic>{
        'platform': platformId,
        'page_index': pageIndex,
      },
    );
    final payload = _asMap(response.data);
    return HomePageResult(
      sections: _parseSections(payload, platformId),
      hasMore: _readBool(payload['has_more']),
    );
  }

  Future<HomePageResult> fetchDiscoverPage({required String platformId}) async {
    final response = await _dio.get(
      '/v1/page/discover',
      queryParameters: <String, dynamic>{'platform': platformId},
    );
    final payload = _asMap(response.data);
    return HomePageResult(
      sections: _parseSections(payload, platformId),
      hasMore: false,
    );
  }

  Future<RecommendSongListInfo> fetchRecommendSongList(
    RecommendSongListRequest request,
  ) async {
    final response = await _dio.get(
      '/v1/page/recommend/song-list',
      queryParameters: <String, dynamic>{
        'platform': request.platform,
        'id': request.id,
      },
    );
    // response_body: "info" 使 HTTP 响应直接成为详情对象，不含 info 包装。
    final payload = _asMap(response.data);
    final id = '${payload['id'] ?? ''}'.trim();
    final title = '${payload['title'] ?? ''}'.trim();
    if (id.isEmpty || title.isEmpty) {
      throw const AppException(
        NetworkFailure('Invalid recommend song list response'),
      );
    }
    return RecommendSongListInfo(
      id: id,
      title: title,
      cover: '${payload['cover'] ?? ''}'.trim(),
      description: '${payload['description'] ?? ''}'.trim(),
      songs: _parseItems(
        payload['songs'],
        (item) => SongInfo.fromMap(item, fallbackPlatform: request.platform),
        (item) => item.id.isNotEmpty && item.name.isNotEmpty,
      ),
    );
  }

  List<HomePageSection> _parseSections(
    Map<String, dynamic> payload,
    String fallbackPlatform,
  ) {
    final rawSections = payload['sections'];
    if (rawSections is! List) {
      throw const AppException(
        NetworkFailure('Invalid page response: missing sections'),
      );
    }
    final sections = <HomePageSection>[];
    for (final rawSection in rawSections) {
      if (rawSection is! Map) {
        continue;
      }
      final section = _parseSection(
        rawSection.map((key, value) => MapEntry('$key', value)),
        fallbackPlatform,
      );
      if (section != null && !section.isEmpty) {
        sections.add(section);
      }
    }
    return List<HomePageSection>.unmodifiable(sections);
  }

  HomePageSection? _parseSection(
    Map<String, dynamic> raw,
    String fallbackPlatform,
  ) {
    final sectionTypeCode = _readInt(raw['section_type']);
    final sectionType = parseHomeSectionType(sectionTypeCode);
    if (sectionType == HomeSectionType.quickEntries) {
      final section = HomePageSection(
        sectionTypeCode: sectionTypeCode,
        sectionType: sectionType,
        resourceType: null,
        title: '${raw['title'] ?? ''}',
        entries: _parseItems(
          raw['entries'],
          (item) {
            final targetType = parseHomePageEntryTargetType(
              _readInt(item['target_type']),
            );
            if (targetType == null) {
              throw const FormatException('Unknown page entry target type');
            }
            return HomePageEntry(
              targetType: targetType,
              targetId: '${item['target_id'] ?? ''}'.trim(),
              title: '${item['title'] ?? ''}'.trim(),
              subtitle: '${item['subtitle'] ?? ''}'.trim(),
              cover: '${item['cover'] ?? ''}'.trim(),
            );
          },
          (item) => item.targetId.isNotEmpty && item.title.isNotEmpty,
        ),
      );
      return section.isEmpty ? null : section;
    }
    final resourceType = parseHomeResourceType('${raw['resource_type'] ?? ''}');
    if (resourceType == null) {
      return null;
    }
    final section = HomePageSection(
      sectionTypeCode: sectionTypeCode,
      sectionType: sectionType,
      resourceType: resourceType,
      title: '${raw['title'] ?? ''}',
      songs: resourceType == HomeResourceType.song
          ? _parseItems(
              raw['songs'],
              (item) =>
                  SongInfo.fromMap(item, fallbackPlatform: fallbackPlatform),
              (item) => item.id.isNotEmpty && item.name.isNotEmpty,
            )
          : const <SongInfo>[],
      albums: resourceType == HomeResourceType.album
          ? _parseItems(
              raw['albums'],
              (item) =>
                  AlbumInfo.fromMap(item, fallbackPlatform: fallbackPlatform),
              (item) => item.id.isNotEmpty && item.name.isNotEmpty,
            )
          : const <AlbumInfo>[],
      playlists: resourceType == HomeResourceType.playlist
          ? _parseItems(
              raw['playlists'],
              (item) => PlaylistInfo.fromMap(
                item,
                fallbackPlatform: fallbackPlatform,
              ),
              (item) => item.id.isNotEmpty && item.name.isNotEmpty,
            )
          : const <PlaylistInfo>[],
      mvs: resourceType == HomeResourceType.mv
          ? _parseItems(
              raw['mvs'],
              (item) =>
                  MvInfo.fromMap(item, fallbackPlatform: fallbackPlatform),
              (item) => item.id.isNotEmpty && item.name.isNotEmpty,
            )
          : const <MvInfo>[],
      artists: resourceType == HomeResourceType.artist
          ? _parseItems(
              raw['artists'],
              (item) =>
                  ArtistInfo.fromMap(item, fallbackPlatform: fallbackPlatform),
              (item) => item.id.isNotEmpty && item.name.isNotEmpty,
            )
          : const <ArtistInfo>[],
      rankings: resourceType == HomeResourceType.ranking
          ? _parseItems(
              raw['rankings'],
              (item) =>
                  RankingInfo.fromMap(item, fallbackPlatform: fallbackPlatform),
              (item) => item.id.isNotEmpty && item.id != '-',
            )
          : const <RankingInfo>[],
      radios: resourceType == HomeResourceType.radio
          ? _parseItems(
              raw['radios'],
              (item) =>
                  RadioInfo.fromMap(item, fallbackPlatform: fallbackPlatform),
              (item) => item.id.isNotEmpty && item.name.isNotEmpty,
            )
          : const <RadioInfo>[],
    );
    return section.isEmpty ? null : section;
  }

  List<T> _parseItems<T>(
    dynamic raw,
    T Function(Map<String, dynamic> item) parse,
    bool Function(T item) isValid,
  ) {
    if (raw is! List) {
      return <T>[];
    }
    final result = <T>[];
    for (final value in raw) {
      if (value is! Map) {
        continue;
      }
      try {
        final item = parse(value.map((key, entry) => MapEntry('$key', entry)));
        if (isValid(item)) {
          result.add(item);
        }
      } on FormatException {
        continue;
      }
    }
    return List<T>.unmodifiable(result);
  }

  bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = '$value'.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? -1;
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
