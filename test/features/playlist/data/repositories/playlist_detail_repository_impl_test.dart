import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/playlist/data/datasources/playlist_detail_api_client.dart';
import 'package:he_music_flutter/features/playlist/data/repositories/playlist_detail_repository_impl.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_request.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('fetchInfo delegates to apiClient', () async {
    final fake = _FakePlaylistDetailApiClient();
    final repo = PlaylistDetailRepositoryImpl(fake);

    final request = PlaylistDetailRequest(
      id: 'pl-1',
      platform: 'netease',
      title: 'Test',
    );
    final result = await repo.fetchInfo(request);

    expect(fake.lastInfoRequest, request);
    expect(result.name, 'Test Playlist');
  });

  test('fetchSongs delegates to apiClient', () async {
    final fake = _FakePlaylistDetailApiClient();
    final repo = PlaylistDetailRepositoryImpl(fake);
    final request = PlaylistDetailRequest(
      id: 'pl-1',
      platform: 'netease',
      title: 'Test',
    );

    final result = await repo.fetchSongs(request);

    expect(fake.lastSongsRequest, request);
    expect(result, hasLength(1));
  });

  test('fetchInfo propagates apiClient error', () async {
    final fake = _ThrowingPlaylistDetailApiClient();
    final repo = PlaylistDetailRepositoryImpl(fake);

    expect(
      () => repo.fetchInfo(
        PlaylistDetailRequest(id: 'pl-1', platform: 'netease', title: 'x'),
      ),
      throwsException,
    );
  });
}

class _FakePlaylistDetailApiClient extends PlaylistDetailApiClient {
  _FakePlaylistDetailApiClient() : super(Dio());

  PlaylistDetailRequest? lastInfoRequest;
  PlaylistDetailRequest? lastSongsRequest;

  @override
  Future<PlaylistInfo> fetchInfo(PlaylistDetailRequest request) async {
    lastInfoRequest = request;
    return const PlaylistInfo(
      name: 'Test Playlist',
      id: 'pl-1',
      cover: '',
      creator: '',
      songCount: '0',
      playCount: '0',
      songs: [],
      platform: 'netease',
      description: '',
    );
  }

  @override
  Future<List<SongInfo>> fetchSongs(PlaylistDetailRequest request) async {
    lastSongsRequest = request;
    return <SongInfo>[_song()];
  }
}

class _ThrowingPlaylistDetailApiClient extends PlaylistDetailApiClient {
  _ThrowingPlaylistDetailApiClient() : super(Dio());

  @override
  Future<PlaylistInfo> fetchInfo(PlaylistDetailRequest request) {
    throw Exception('network error');
  }
}

SongInfo _song() {
  return const SongInfo(
    name: 'Song',
    subtitle: '',
    id: 'song-1',
    duration: 0,
    mvId: '',
    album: SongInfoAlbumInfo(name: '', id: ''),
    artists: <SongInfoArtistInfo>[],
    links: <LinkInfo>[],
    platform: 'netease',
    cover: '',
  );
}
