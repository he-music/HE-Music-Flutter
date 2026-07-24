import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/song/data/datasources/song_detail_api_client.dart';
import 'package:he_music_flutter/features/song/data/repositories/song_detail_repository_impl.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_content.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_relations.dart';
import 'package:he_music_flutter/features/song/domain/entities/song_detail_request.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('fetchDetail delegates to apiClient', () async {
    final fake = _FakeSongDetailApiClient();
    final repo = SongDetailRepositoryImpl(fake);

    final request = SongDetailRequest(
      id: 's1',
      platform: 'netease',
      title: 'x',
    );
    final result = await repo.fetchDetail(request);

    expect(fake.lastDetailRequest, request);
    expect(result.song.name, 'Test Song');
  });

  test('fetchRelations delegates to apiClient', () async {
    final fake = _FakeSongDetailApiClient();
    final repo = SongDetailRepositoryImpl(fake);

    final request = SongDetailRequest(
      id: 's1',
      platform: 'netease',
      title: 'x',
    );
    final result = await repo.fetchRelations(request);

    expect(fake.lastRelationsRequest, request);
    expect(result.similarSongs, hasLength(1));
  });

  test('fetchDetail propagates apiClient error', () async {
    final fake = _ThrowingSongDetailApiClient();
    final repo = SongDetailRepositoryImpl(fake);

    expect(
      () => repo.fetchDetail(
        SongDetailRequest(id: 's1', platform: 'netease', title: 'x'),
      ),
      throwsException,
    );
  });
}

SongInfo _makeSongInfo(String id, String name) => SongInfo(
  name: name,
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

class _FakeSongDetailApiClient extends SongDetailApiClient {
  _FakeSongDetailApiClient() : super(Dio());

  SongDetailRequest? lastDetailRequest;
  SongDetailRequest? lastRelationsRequest;

  @override
  Future<SongDetailContent> fetchDetail(SongDetailRequest request) async {
    lastDetailRequest = request;
    return SongDetailContent(
      song: _makeSongInfo('s1', 'Test Song'),
      publishTime: '2024-01-01',
      language: 'Chinese',
    );
  }

  @override
  Future<SongDetailRelations> fetchRelations(SongDetailRequest request) async {
    lastRelationsRequest = request;
    return SongDetailRelations(similarSongs: [_makeSongInfo('s2', 'Similar')]);
  }
}

class _ThrowingSongDetailApiClient extends SongDetailApiClient {
  _ThrowingSongDetailApiClient() : super(Dio());

  @override
  Future<SongDetailContent> fetchDetail(SongDetailRequest request) =>
      throw Exception('network error');

  @override
  Future<SongDetailRelations> fetchRelations(SongDetailRequest request) =>
      throw Exception('network error');
}
