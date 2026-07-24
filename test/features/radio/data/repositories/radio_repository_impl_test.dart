import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/radio/data/datasources/radio_api_client.dart';
import 'package:he_music_flutter/features/radio/data/repositories/radio_repository_impl.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('fetchGroups delegates to apiClient', () async {
    final fake = _FakeRadioApiClient();
    final repo = RadioRepositoryImpl(fake);

    final result = await repo.fetchGroups(platform: 'netease');

    expect(fake.lastGroupsPlatform, 'netease');
    expect(result, hasLength(1));
    expect(result.first.name, 'Group');
  });

  test('fetchSongs delegates to apiClient', () async {
    final fake = _FakeRadioApiClient();
    final repo = RadioRepositoryImpl(fake);

    final result = await repo.fetchSongs(
      id: 'r-1',
      platform: 'qq',
      pageIndex: 2,
      pageSize: 20,
    );

    expect(fake.lastSongsId, 'r-1');
    expect(fake.lastSongsPlatform, 'qq');
    expect(fake.lastSongsPageIndex, 2);
    expect(fake.lastSongsPageSize, 20);
    expect(result, hasLength(1));
  });

  test('fetchGroups propagates apiClient error', () async {
    final fake = _ThrowingRadioApiClient();
    final repo = RadioRepositoryImpl(fake);

    expect(() => repo.fetchGroups(platform: 'netease'), throwsException);
  });
}

SongInfo _makeSongInfo(String id) => SongInfo(
  name: 'Song',
  subtitle: '',
  id: id,
  duration: 180,
  mvId: '',
  album: const SongInfoAlbumInfo(name: '', id: ''),
  artists: const [],
  links: const [],
  platform: 'netease',
  cover: '',
);

class _FakeRadioApiClient extends RadioApiClient {
  _FakeRadioApiClient() : super(Dio());

  String? lastGroupsPlatform;
  String? lastSongsId;
  String? lastSongsPlatform;
  int? lastSongsPageIndex;
  int? lastSongsPageSize;

  @override
  Future<List<RadioGroupInfo>> fetchGroups({required String platform}) async {
    lastGroupsPlatform = platform;
    return [
      RadioGroupInfo(name: 'Group', radios: const [], platform: platform),
    ];
  }

  @override
  Future<List<SongInfo>> fetchSongs({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 50,
  }) async {
    lastSongsId = id;
    lastSongsPlatform = platform;
    lastSongsPageIndex = pageIndex;
    lastSongsPageSize = pageSize;
    return [_makeSongInfo('s1')];
  }
}

class _ThrowingRadioApiClient extends RadioApiClient {
  _ThrowingRadioApiClient() : super(Dio());

  @override
  Future<List<RadioGroupInfo>> fetchGroups({required String platform}) =>
      throw Exception('network error');

  @override
  Future<List<SongInfo>> fetchSongs({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 50,
  }) => throw Exception('network error');
}
