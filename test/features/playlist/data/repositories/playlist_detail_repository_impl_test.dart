import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/playlist/data/datasources/playlist_detail_api_client.dart';
import 'package:he_music_flutter/features/playlist/data/repositories/playlist_detail_repository_impl.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_content.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_request.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('fetchDetail delegates to apiClient', () async {
    final fake = _FakePlaylistDetailApiClient();
    final repo = PlaylistDetailRepositoryImpl(fake);

    final request = PlaylistDetailRequest(
      id: 'pl-1',
      platform: 'netease',
      title: 'Test',
    );
    final result = await repo.fetchDetail(request);

    expect(fake.lastRequest, request);
    expect(result.info.name, 'Test Playlist');
  });

  test('fetchDetail propagates apiClient error', () async {
    final fake = _ThrowingPlaylistDetailApiClient();
    final repo = PlaylistDetailRepositoryImpl(fake);

    expect(
      () => repo.fetchDetail(
        PlaylistDetailRequest(id: 'pl-1', platform: 'netease', title: 'x'),
      ),
      throwsException,
    );
  });
}

class _FakePlaylistDetailApiClient extends PlaylistDetailApiClient {
  _FakePlaylistDetailApiClient() : super(Dio());

  PlaylistDetailRequest? lastRequest;

  @override
  Future<PlaylistDetailContent> fetchDetail(
    PlaylistDetailRequest request,
  ) async {
    lastRequest = request;
    return PlaylistDetailContent(
      info: const PlaylistInfo(
        name: 'Test Playlist',
        id: 'pl-1',
        cover: '',
        creator: '',
        songCount: '0',
        playCount: '0',
        songs: [],
        platform: 'netease',
        description: '',
      ),
      songs: const [],
    );
  }
}

class _ThrowingPlaylistDetailApiClient extends PlaylistDetailApiClient {
  _ThrowingPlaylistDetailApiClient() : super(Dio());

  @override
  Future<PlaylistDetailContent> fetchDetail(PlaylistDetailRequest request) =>
      throw Exception('network error');
}
