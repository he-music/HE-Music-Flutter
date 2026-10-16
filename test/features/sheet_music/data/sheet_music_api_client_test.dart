import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/sheet_music/data/datasources/sheet_music_api_client.dart';
import 'package:he_music_flutter/features/sheet_music/domain/entities/sheet_music_info.dart';
import 'package:he_music_flutter/features/sheet_music/domain/entities/sheet_music_not_implemented_exception.dart';

void main() {
  test(
    'list GET sends only platform and string song_id without pagination',
    () async {
      final requests = <RequestOptions>[];
      final client = _client({
        'list': [
          {'id': '0009007199254740993', 'title': '吉他谱'},
          {'id': 'second', 'title': ''},
        ],
      }, onRequest: requests.add);
      final list = await client.fetchList(platform: 'qq', songId: '000123');
      expect(requests.single.path, '/v1/song/sheet-music');
      expect(requests.single.method, 'GET');
      expect(requests.single.queryParameters, {
        'platform': 'qq',
        'song_id': '000123',
      });
      expect(requests.single.extra['silentErrorMessage'], true);
      expect(list.map((sheet) => sheet.id), ['0009007199254740993', 'second']);
      expect(list.first.pageUrls, isEmpty);
    },
  );

  test(
    'detail reads direct object and uses id plus original string song_id',
    () async {
      final requests = <RequestOptions>[];
      final sheet = await _client(
        {
          'id': '001',
          'title': '详情标题',
          'song_name': '歌曲',
          'uploader': '上传者',
          'instruments': ['吉他'],
          'notation_types': ['简谱', '六线谱'],
          'arrangement_type': '弹唱版',
          'difficulty': '初级',
          'original_key': 'C',
          'bpm': 120,
          'cover': 'https://example.com/cover.jpg',
          'page_urls': [
            'https://example.com/2.jpg',
            'https://example.com/1.jpg',
          ],
          'page_count': 3,
          'platform': 'netease',
        },
        onRequest: requests.add,
      ).fetchDetail(platform: 'netease', id: '001', songId: '000123');
      expect(requests.single.path, '/v1/sheet-music');
      expect(requests.single.method, 'GET');
      expect(requests.single.queryParameters, {
        'platform': 'netease',
        'id': '001',
        'song_id': '000123',
      });
      expect(sheet.id, '001');
      expect(sheet.title, '详情标题');
      expect(sheet.songName, '歌曲');
      expect(sheet.uploader, '上传者');
      expect(sheet.instruments, ['吉他']);
      expect(sheet.notationTypes, ['简谱', '六线谱']);
      expect(sheet.arrangementType, '弹唱版');
      expect(sheet.difficulty, '初级');
      expect(sheet.originalKey, 'C');
      expect(sheet.bpm, 120);
      expect(sheet.cover, 'https://example.com/cover.jpg');
      expect(sheet.pageUrls, [
        'https://example.com/2.jpg',
        'https://example.com/1.jpg',
      ]);
      expect(sheet.pageCount, 3);
      expect(sheet.platform, 'netease');
    },
  );

  for (final raw in <Map<String, dynamic>>[
    {},
    {
      'id': null,
      'title': '',
      'page_urls': null,
      'instruments': [],
      'notation_types': [],
      'bpm': 0,
    },
  ]) {
    test('partial payload tolerates absent/null/empty fields: $raw', () {
      final sheet = SheetMusicInfo.fromMap(raw);
      expect(sheet.id, isA<String>());
      expect(sheet.id, '');
      expect(sheet.title, '');
      expect(sheet.uploader, '');
      expect(sheet.originalKey, '');
      expect(sheet.bpm, 0);
      expect(sheet.pageCount, 0);
      expect(sheet.cover, '');
      expect(sheet.platform, '');
      expect(sheet.pageUrls, isEmpty);
      expect(sheet.instruments, isEmpty);
      expect(sheet.notationTypes, isEmpty);
    });
  }

  test(
    'empty image entries are ignored without synthesizing missing pages',
    () {
      final sheet = SheetMusicInfo.fromMap({
        'id': '0001',
        'page_count': 9,
        'bpm': null,
        'page_urls': ['', ' second ', null, 'first', '  '],
      });
      expect(sheet.pageUrls, ['second', 'first']);
      expect(sheet.pageUrls, hasLength(2));
      expect(sheet.id, '0001');
      expect(sheet.bpm, 0);
      expect(() => sheet.pageUrls.add('third'), throwsUnsupportedError);
    },
  );

  for (final response in [
    (status: 501, body: <String, dynamic>{}),
    (status: 500, body: <String, dynamic>{'reason': 'NotImplemented'}),
    (
      status: 501,
      body: <String, dynamic>{'code': 501, 'reason': 'NOT_IMPLEMENTED'},
    ),
    (status: 200, body: <String, dynamic>{'code': 'NotImplemented'}),
    (
      status: 500,
      body: <String, dynamic>{
        'data': {'message': 'NotImplemented'},
      },
    ),
  ]) {
    for (final detail in [false, true]) {
      test(
        'NotImplemented remains distinct from empty success: $response detail=$detail',
        () async {
          final client = _client(response.body, status: response.status);
          final future = detail
              ? client.fetchDetail(platform: 'qq', songId: '001', id: '002')
              : client.fetchList(platform: 'qq', songId: '001');
          await expectLater(
            future,
            throwsA(isA<SheetMusicNotImplementedException>()),
          );
        },
      );
    }
  }

  test(
    'ordinary failures are preserved and successful empty list is empty',
    () async {
      final failed = _client({'message': 'Service unavailable'}, status: 503);
      await expectLater(
        failed.fetchList(platform: 'qq', songId: 's'),
        throwsA(isA<DioException>()),
      );
      expect(
        await _client({'list': []}).fetchList(platform: 'qq', songId: 's'),
        isEmpty,
      );
    },
  );
}

SheetMusicApiClient _client(
  dynamic body, {
  int status = 200,
  void Function(RequestOptions)? onRequest,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        onRequest?.call(options);
        if (status >= 400) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: status,
                data: body,
              ),
            ),
          );
        } else {
          handler.resolve(
            Response(requestOptions: options, statusCode: status, data: body),
          );
        }
      },
    ),
  );
  return SheetMusicApiClient(dio);
}
