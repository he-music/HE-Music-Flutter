import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/features/home/data/datasources/home_page_api_client.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_section.dart';

void main() {
  test('推荐页按顺序解析七类动态区块和分页参数', () async {
    String? path;
    Map<String, dynamic>? query;
    final client = _createClient(
      <String, dynamic>{
        'sections': <Map<String, dynamic>>[
          _section(2, 'song', '新歌', 'songs', _song('song-1')),
          _section(3, 'album', '新碟', 'albums', _album('album-1')),
          _section(1, 'playlist', '歌单', 'playlists', _playlist('playlist-1')),
          _section(1, 'mv', '视频', 'mvs', _mv('mv-1')),
          _section(99, 'artist', '歌手', 'artists', _artist('artist-1')),
          _section(4, 'ranking', '榜单', 'rankings', _ranking('ranking-1')),
          _section(5, 'radio', '电台', 'radios', _radio('radio-1')),
        ],
        'has_more': true,
      },
      onFetch: (requestPath, parameters) {
        path = requestPath;
        query = parameters;
      },
    );

    final result = await client.fetchRecommendPage(
      platformId: 'qq',
      pageIndex: 3,
    );

    expect(path, '/v1/page/recommend');
    expect(query, <String, dynamic>{'platform': 'qq', 'page_index': 3});
    expect(result.hasMore, isTrue);
    expect(
      result.sections.map((section) => section.resourceType),
      HomeResourceType.values,
    );
    expect(result.sections.map((section) => section.title), <String>[
      '新歌',
      '新碟',
      '歌单',
      '视频',
      '歌手',
      '榜单',
      '电台',
    ]);
    expect(result.sections[4].sectionType, HomeSectionType.unknown);
    expect(result.sections[4].sectionTypeCode, 99);
    expect(result.sections[5].rankings.single.previewSongs.single.name, '歌曲');
  });

  test('未知资源、空区块和跨类型载荷被忽略且不猜类型', () async {
    final client = _createClient(<String, dynamic>{
      'sections': <Map<String, dynamic>>[
        _section(1, 'future', '未知', 'songs', _song('song-1')),
        <String, dynamic>{
          'section_type': 1,
          'resource_type': 'playlist',
          'title': '错误载荷',
          'songs': <Map<String, dynamic>>[_song('song-2')],
          'playlists': <dynamic>[],
        },
        <String, dynamic>{
          'section_type': 1,
          'resource_type': 'song',
          'title': '空区块',
          'songs': <dynamic>[],
        },
      ],
      'has_more': false,
    });

    final result = await client.fetchRecommendPage(
      platformId: 'qq',
      pageIndex: 1,
    );

    expect(result.sections, isEmpty);
  });

  test('发现页只读取 sections，不回退 deprecated 字段', () async {
    final client = _createClient(<String, dynamic>{
      'sections': <dynamic>[],
      'new_songs': <Map<String, dynamic>>[_song('legacy')],
      'featured_playlists': <Map<String, dynamic>>[_playlist('legacy')],
    });

    final result = await client.fetchDiscoverPage(platformId: 'qq');

    expect(result.sections, isEmpty);
    expect(result.hasMore, isFalse);
  });

  test('sections 缺失时抛出 AppException', () {
    final client = _createClient(<String, dynamic>{'has_more': false});

    expect(
      () => client.fetchDiscoverPage(platformId: 'qq'),
      throwsA(isA<AppException>()),
    );
  });
}

Map<String, dynamic> _section(
  int sectionType,
  String resourceType,
  String title,
  String field,
  Map<String, dynamic> item,
) {
  return <String, dynamic>{
    'section_type': sectionType,
    'resource_type': resourceType,
    'title': title,
    field: <Map<String, dynamic>>[item],
  };
}

Map<String, dynamic> _song(String id) => <String, dynamic>{
  'id': id,
  'name': '歌曲',
  'artists': <Map<String, dynamic>>[
    <String, dynamic>{'id': 'artist-1', 'name': '歌手'},
  ],
};

Map<String, dynamic> _album(String id) => <String, dynamic>{
  'id': id,
  'name': '专辑',
};

Map<String, dynamic> _playlist(String id) => <String, dynamic>{
  'id': id,
  'name': '歌单',
};

Map<String, dynamic> _mv(String id) => <String, dynamic>{
  'id': id,
  'name': '视频',
};

Map<String, dynamic> _artist(String id) => <String, dynamic>{
  'id': id,
  'name': '歌手',
};

Map<String, dynamic> _ranking(String id) => <String, dynamic>{
  'id': id,
  'name': '榜单',
  'songs': <Map<String, dynamic>>[_song('preview-1')],
};

Map<String, dynamic> _radio(String id) => <String, dynamic>{
  'id': id,
  'name': '电台',
};

HomePageApiClient _createClient(
  dynamic payload, {
  void Function(String path, Map<String, dynamic> query)? onFetch,
}) {
  final dio = Dio();
  dio.httpClientAdapter = _MockAdapter(payload, onFetch);
  return HomePageApiClient(dio);
}

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.payload, this.onFetch);

  final dynamic payload;
  final void Function(String path, Map<String, dynamic> query)? onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onFetch?.call(options.path, options.queryParameters);
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
