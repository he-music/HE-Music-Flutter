import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../domain/entities/my_profile.dart';

class MyOverviewApiClient {
  const MyOverviewApiClient(this._dio);

  final Dio _dio;

  Future<MyProfile> fetchProfile() async {
    final response = await _dio.get('/v1/user/info');
    final data = _asMap(response.data);
    return MyProfile(
      id: _asString(data['id']),
      username: _asString(data['username']),
      nickname: _asString(data['nickname']),
      email: _asString(data['email']),
      status: _asInt(data['status']),
      avatarUrl: _asString(data['avatar']),
    );
  }

  Future<int> fetchFavouriteSongCount() {
    return _fetchCount('/v1/user/favourite/songs');
  }

  Future<int> fetchFavouritePlaylistCount() {
    return _fetchCount('/v1/user/favourite/playlists');
  }

  Future<int> fetchFavouriteArtistCount() {
    return _fetchCount('/v1/user/favourite/artists');
  }

  Future<int> fetchFavouriteAlbumCount() {
    return _fetchCount('/v1/user/favourite/albums');
  }

  Future<int> fetchCreatedPlaylistCount() {
    return _fetchCount('/v1/user/playlists');
  }

  Future<int> _fetchCount(String path) async {
    final response = await _dio.get(
      path,
      queryParameters: const <String, dynamic>{'page_size': 1, 'page_index': 1},
    );
    final data = _asMap(response.data);
    final listLength = _listLength(data['list']);
    final totalCount = _tryParseInt(data['total_count']) ?? 0;
    return math.max(totalCount, listLength);
  }

  int _listLength(dynamic value) {
    if (value is List) {
      return value.length;
    }
    return 0;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return <String, dynamic>{};
  }

  String _asString(dynamic value) {
    if (value == null) {
      return '';
    }
    return '$value';
  }

  int _asInt(dynamic value) {
    return _tryParseInt(value) ?? 0;
  }

  int? _tryParseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value');
  }
}
