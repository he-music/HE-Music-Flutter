import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/song/data/datasources/song_detail_api_client.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_request.dart';

void main() {
  const request = SongDetailRequest(id: 'source', platform: 'qq', title: '歌曲');
  const song = {'id': 'source', 'name': '歌曲', 'platform': 'qq'};

  test(
    'one detail GET decodes ordered fields and direct sections with resource identities',
    () async {
      final requests = <RequestOptions>[];
      final result = await _client({
        'song': song,
        'fields': [
          {'label': '自定义', 'value': ' 1704067200 '},
          {'label': '自定义', 'value': '2024/1/1（首发）'},
        ],
        'sections': [
          _section('playlist', '歌单标题', 'playlists', [
            {'id': 'p', 'name': '歌单', 'platform': 'netease'},
          ]),
          _section('song', '推荐标题', 'songs', [
            {'id': 's1', 'name': '推荐', 'platform': 'kugou'},
          ]),
          _section('album', '专辑标题', 'albums', [
            {'id': 'a', 'name': '专辑', 'platform': 'kuwo'},
          ]),
          _section('mv', '视频标题', 'mvs', [
            {'id': 'm', 'name': '视频', 'duration': 123},
          ]),
          _section('song', '版本标题', 'songs', [
            {'id': 's2', 'name': '版本'},
          ]),
        ],
      }, onRequest: requests.add).fetchDetail(request);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.path, '/v1/song/detail');
      expect(requests.single.queryParameters, {
        'platform': 'qq',
        'id': 'source',
      });
      expect(result.song.id, 'source');
      expect(result.fields.map((field) => field.label), ['自定义', '自定义']);
      expect(result.fields.map((field) => field.value), [
        ' 1704067200 ',
        '2024/1/1（首发）',
      ]);
      expect(result.sections.map((section) => section.title), [
        '歌单标题',
        '推荐标题',
        '专辑标题',
        '视频标题',
        '版本标题',
      ]);
      expect(result.sections[0].playlists.single.platform, 'netease');
      expect(result.sections[1].songs.single.platform, 'kugou');
      expect(result.sections[2].albums.single.platform, 'kuwo');
      expect(result.sections[3].mvs.single.platform, 'qq');
      expect(result.sections[3].mvs.single.duration, 123);
      expect(result.sections[4].songs.single.id, 's2');
    },
  );

  test(
    'sheet_music sections decode the shared sheet model from sheet_music',
    () async {
      final result = await _client({
        'song': song,
        'sections': [
          _section('sheet_music', '这首歌的曲谱', 'sheet_music', [
            {
              'id': '0009007199254740993',
              'title': '吉他弹唱谱',
              'song_name': '歌曲',
              'cover': 'https://example.com/sheet.jpg',
              'platform': 'netease',
              'instruments': ['吉他'],
              'notation_types': ['六线谱'],
              'original_key': 'C',
              'page_count': 3,
            },
            null,
            'invalid',
            {'id': 'second', 'title': '钢琴谱'},
          ]),
        ],
      }).fetchDetail(request);
      final section = result.sections.single;
      expect(section.resourceType, 'sheet_music');
      expect(section.title, '这首歌的曲谱');
      expect(section.isEmpty, false);
      expect(section.sheetMusic.map((sheet) => sheet.id), [
        '0009007199254740993',
        'second',
      ]);
      final sheet = section.sheetMusic.first;
      expect(sheet.title, '吉他弹唱谱');
      expect(sheet.songName, '歌曲');
      expect(sheet.cover, 'https://example.com/sheet.jpg');
      expect(sheet.platform, 'netease');
      expect(sheet.instruments, ['吉他']);
      expect(sheet.notationTypes, ['六线谱']);
      expect(sheet.originalKey, 'C');
      expect(sheet.pageCount, 3);
    },
  );

  for (final fields in <Map<String, dynamic>>[
    {},
    {'fields': null},
    {'fields': []},
  ]) {
    for (final sections in <Map<String, dynamic>>[
      {},
      {'sections': null},
      {'sections': []},
    ]) {
      test(
        'missing/null/empty arrays keep primary detail ($fields, $sections)',
        () async {
          final result = await _client({
            'song': song,
            ...fields,
            ...sections,
          }).fetchDetail(request);
          expect(result.song.id, 'source');
          expect(result.fields, isEmpty);
          expect(result.sections, isEmpty);
        },
      );
    }
  }

  test(
    'resource arrays accept missing/null/empty and unknown or mismatched blocks are empty',
    () async {
      final result = await _client({
        'song': song,
        'fields': [
          {'label': '信息', 'value': '仍可展示'},
        ],
        'sections': [
          {'resource_type': 'sheet_music', 'title': '缺失曲谱'},
          {
            'resource_type': 'sheet_music',
            'title': 'null曲谱',
            'sheet_music': null,
          },
          _section('sheet_music', '空曲谱', 'sheet_music', []),
          _section('sheet_music', '不匹配曲谱', 'songs', [
            {'id': 's', 'name': '歌曲'},
          ]),
          {'resource_type': 'song', 'title': '缺失'},
          {'resource_type': 'album', 'title': 'null', 'albums': null},
          _section('mv', '空', 'mvs', []),
          _section('playlist', '不匹配', 'songs', [
            {'id': 's', 'name': '歌曲'},
          ]),
          _section('future', '未知', 'songs', [
            {'id': 's', 'name': '歌曲'},
          ]),
        ],
      }).fetchDetail(request);
      expect(result.fields.single.value, '仍可展示');
      expect(result.sections.every((section) => section.isEmpty), true);
      for (final section in result.sections) {
        expect(section.albums, isEmpty);
        expect(section.mvs, isEmpty);
        expect(section.playlists, isEmpty);
        expect(section.sheetMusic, isEmpty);
      }
    },
  );

  test('detail requires song in the new response structure', () async {
    for (final payload in <Map<String, dynamic>>[
      song,
      {'song': null},
      {'song': {}},
    ]) {
      await expectLater(_client(payload).fetchDetail(request), throwsException);
    }
  });
}

Map<String, dynamic> _section(
  String resource,
  String title,
  String field,
  List<dynamic> items,
) => {'resource_type': resource, 'title': title, field: items};

SongDetailApiClient _client(
  Map<String, dynamic> payload, {
  void Function(RequestOptions)? onRequest,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        onRequest?.call(options);
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            data: payload,
            statusCode: 200,
          ),
        );
      },
    ),
  );
  return SongDetailApiClient(dio);
}
