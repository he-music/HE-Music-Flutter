import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/album/data/datasources/album_detail_api_client.dart';
import 'package:he_music_flutter/features/album/data/repositories/album_detail_repository_impl.dart';
import 'package:he_music_flutter/features/album/domain/entities/album_detail_content.dart';
import 'package:he_music_flutter/features/album/domain/entities/album_detail_request.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('fetchDetail delegates to apiClient', () async {
    final fake = _FakeAlbumDetailApiClient();
    final repo = AlbumDetailRepositoryImpl(fake);

    final request = AlbumDetailRequest(
      id: 'a1',
      platform: 'netease',
      title: 'Album',
    );
    final result = await repo.fetchDetail(request);

    expect(fake.lastRequest, request);
    expect(result.info.name, 'Test Album');
  });

  test('fetchDetail propagates apiClient error', () async {
    final fake = _ThrowingAlbumDetailApiClient();
    final repo = AlbumDetailRepositoryImpl(fake);

    expect(
      () => repo.fetchDetail(
        AlbumDetailRequest(id: 'a1', platform: 'netease', title: 'x'),
      ),
      throwsException,
    );
  });
}

class _FakeAlbumDetailApiClient extends AlbumDetailApiClient {
  _FakeAlbumDetailApiClient() : super(Dio());

  AlbumDetailRequest? lastRequest;

  @override
  Future<AlbumDetailContent> fetchDetail(AlbumDetailRequest request) async {
    lastRequest = request;
    return const AlbumDetailContent(
      info: AlbumInfo(
        name: 'Test Album',
        id: 'a1',
        cover: '',
        artists: [],
        songCount: '10',
        publishTime: '2024',
        songs: [],
        description: '',
        platform: 'netease',
        language: '',
        genre: '',
        type: 0,
        isFinished: false,
        playCount: '',
      ),
      songs: [],
    );
  }
}

class _ThrowingAlbumDetailApiClient extends AlbumDetailApiClient {
  _ThrowingAlbumDetailApiClient() : super(Dio());

  @override
  Future<AlbumDetailContent> fetchDetail(AlbumDetailRequest request) =>
      throw Exception('network error');
}
