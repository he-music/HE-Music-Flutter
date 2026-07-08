import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/features/radio/data/datasources/radio_api_client.dart';

/// 记录请求参数的 fake Dio。
class _FakeDio implements Dio {
  _FakeDio(this._response);
  final dynamic _response;

  String? lastPath;
  Map<String, dynamic>? lastQueryParameters;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastPath = path;
    lastQueryParameters = queryParameters;
    return Response<T>(
      data: _response as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  // Dio 接口的其余方法 — 测试中不会调用。
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RadioApiClient', () {
    group('fetchGroups', () {
      test('应正确解析 groups 列表', () async {
        final fake = _FakeDio({
          'groups': [
            {
              'name': '热门',
              'platform': 'qq',
              'radios': [
                {'id': 'r1', 'name': 'Radio 1', 'platform': 'qq', 'cover': ''},
              ],
            },
          ],
        });
        final client = RadioApiClient(fake);

        final groups = await client.fetchGroups(platform: 'qq');
        expect(groups, hasLength(1));
        expect(groups.first.name, '热门');
      });

      test('应传递正确的 queryParameters', () async {
        final fake = _FakeDio({'groups': []});
        final client = RadioApiClient(fake);

        await client.fetchGroups(platform: 'netease');

        expect(fake.lastPath, '/v1/radios');
        expect(fake.lastQueryParameters, {'platform': 'netease'});
      });

      test('应在 groups 缺失时抛出 AppException', () async {
        final fake = _FakeDio({'data': 'no groups field'});
        final client = RadioApiClient(fake);

        expect(
          () => client.fetchGroups(platform: 'qq'),
          throwsA(isA<AppException>()),
        );
      });

      test('应在 groups 非 List 时抛出 AppException', () async {
        final fake = _FakeDio({'groups': 'not-a-list'});
        final client = RadioApiClient(fake);

        expect(
          () => client.fetchGroups(platform: 'qq'),
          throwsA(isA<AppException>()),
        );
      });
    });

    group('fetchSongs', () {
      test('应正确解析 songs 列表', () async {
        final fake = _FakeDio({
          'list': [
            {'id': 's1', 'name': 'Song 1', 'platform': 'qq'},
          ],
        });
        final client = RadioApiClient(fake);

        final songs = await client.fetchSongs(id: 'r1', platform: 'qq');
        expect(songs, hasLength(1));
      });

      test('应归一化 pageIndex <= 0 为 1', () async {
        final fake = _FakeDio({'list': []});
        final client = RadioApiClient(fake);

        await client.fetchSongs(id: 'r1', platform: 'qq', pageIndex: -5);

        expect(fake.lastQueryParameters, {
          'id': 'r1',
          'platform': 'qq',
          'page_index': 1,
          'page_size': 50,
        });
      });

      test('应归一化 pageSize <= 0 为 50', () async {
        final fake = _FakeDio({'list': []});
        final client = RadioApiClient(fake);

        await client.fetchSongs(id: 'r1', platform: 'qq', pageSize: 0);

        expect(fake.lastQueryParameters, {
          'id': 'r1',
          'platform': 'qq',
          'page_index': 1,
          'page_size': 50,
        });
      });

      test('应使用自定义 pageIndex 和 pageSize', () async {
        final fake = _FakeDio({'list': []});
        final client = RadioApiClient(fake);

        await client.fetchSongs(
          id: 'r1',
          platform: 'qq',
          pageIndex: 3,
          pageSize: 20,
        );

        expect(fake.lastQueryParameters, {
          'id': 'r1',
          'platform': 'qq',
          'page_index': 3,
          'page_size': 20,
        });
      });

      test('应在 list 缺失时抛出 AppException', () async {
        final fake = _FakeDio({'data': 'no list field'});
        final client = RadioApiClient(fake);

        expect(
          () => client.fetchSongs(id: 'r1', platform: 'qq'),
          throwsA(isA<AppException>()),
        );
      });
    });
  });
}
