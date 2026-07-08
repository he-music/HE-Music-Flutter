import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/features/player/data/datasources/artist_photo_api_client.dart';

void main() {
  group('ArtistPhotoApiClient', () {
    test('listPhotos 应正确解析 urls 列表', () async {
      final client = _createClient({
        'urls': ['https://a.com/1.jpg', 'https://a.com/2.jpg'],
      });

      final result = await client.listPhotos(
        platform: 'qq',
        ids: ['artist-1'],
        names: ['周杰伦'],
      );

      expect(result, hasLength(2));
      expect(result.first, 'https://a.com/1.jpg');
    });

    test('listPhotos 应过滤空字符串', () async {
      final client = _createClient({
        'urls': ['https://a.com/1.jpg', '', '  ', 'https://a.com/3.jpg'],
      });

      final result = await client.listPhotos(platform: 'qq', names: ['Test']);
      expect(result, hasLength(2));
    });

    test('listPhotos 在 urls 不是 List 时返回空列表', () async {
      final client = _createClient({'urls': 'not a list'});

      final result = await client.listPhotos(platform: 'qq', names: ['Test']);
      expect(result, isEmpty);
    });

    test('listPhotos 在无 urls 字段时返回空列表', () async {
      final client = _createClient({'other': 'data'});

      final result = await client.listPhotos(platform: 'qq', names: ['Test']);
      expect(result, isEmpty);
    });

    test('listPhotos 在非 Map 响应时应抛出 AppException', () async {
      // 有效 JSON 但不是 Map（是 List），触发 _asMap 抛出 AppException
      final client = _createClient([1, 2, 3]);

      expect(
        () => client.listPhotos(platform: 'qq', names: ['Test']),
        throwsA(isA<AppException>()),
      );
    });
  });
}

/// 创建使用模拟 HTTP 适配器的 ArtistPhotoApiClient。
ArtistPhotoApiClient _createClient(dynamic payload) {
  final dio = Dio();
  dio.httpClientAdapter = _MockAdapter(payload);
  return ArtistPhotoApiClient(dio);
}

/// 模拟 HTTP 适配器，返回预设的 JSON 响应。
class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._payload);

  final dynamic _payload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(_payload),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
