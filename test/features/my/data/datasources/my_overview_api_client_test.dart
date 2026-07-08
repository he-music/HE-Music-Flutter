import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/my/data/datasources/my_overview_api_client.dart';

void main() {
  group('MyOverviewApiClient', () {
    test('fetchProfile 应正确解析用户信息', () async {
      final client = _createClient({
        'id': 'u-1',
        'username': 'testuser',
        'nickname': 'Test User',
        'email': 'test@example.com',
        'status': 1,
        'avatar': 'https://a.com/avatar.jpg',
      });

      final profile = await client.fetchProfile();
      expect(profile.id, 'u-1');
      expect(profile.username, 'testuser');
      expect(profile.nickname, 'Test User');
      expect(profile.email, 'test@example.com');
      expect(profile.status, 1);
      expect(profile.avatarUrl, 'https://a.com/avatar.jpg');
    });

    test('fetchProfile 在字段缺失时应返回空字符串和 0', () async {
      final client = _createClient(<String, dynamic>{});

      final profile = await client.fetchProfile();
      expect(profile.id, '');
      expect(profile.username, '');
      expect(profile.nickname, '');
      expect(profile.email, '');
      expect(profile.status, 0);
      expect(profile.avatarUrl, '');
    });

    test('_fetchCount 应取 total_count 和 list.length 的最大值', () async {
      // total_count=5, list 有 3 项 → 返回 5
      final client = _createClient({
        'total_count': 5,
        'list': [
          {'id': '1'},
          {'id': '2'},
          {'id': '3'},
        ],
      });

      final count = await client.fetchFavouriteSongCount();
      expect(count, 5);
    });

    test('_fetchCount 当 list 更长时取 list.length', () async {
      final client = _createClient({
        'total_count': 1,
        'list': [
          {'id': '1'},
          {'id': '2'},
          {'id': '3'},
        ],
      });

      final count = await client.fetchFavouriteSongCount();
      expect(count, 3);
    });

    test('_fetchCount 无 total_count 时默认为 0', () async {
      final client = _createClient({
        'list': [
          {'id': '1'},
        ],
      });

      final count = await client.fetchFavouriteSongCount();
      expect(count, 1);
    });

    test('_fetchCount list 不是 List 时返回 0', () async {
      final client = _createClient({'total_count': 0, 'list': 'not a list'});

      final count = await client.fetchFavouritePlaylistCount();
      expect(count, 0);
    });

    test('_fetchCount 在 total_count 为字符串时应正确解析', () async {
      final client = _createClient({'total_count': '42', 'list': []});

      final count = await client.fetchFavouriteArtistCount();
      expect(count, 42);
    });
  });
}

MyOverviewApiClient _createClient(dynamic payload) {
  final dio = Dio();
  dio.httpClientAdapter = _MockAdapter(payload);
  return MyOverviewApiClient(dio);
}

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
