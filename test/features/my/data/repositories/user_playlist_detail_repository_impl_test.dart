import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/my/data/datasources/user_playlist_detail_api_client.dart';
import 'package:he_music_flutter/features/my/data/datasources/user_playlist_song_api_client.dart';
import 'package:he_music_flutter/features/my/data/repositories/user_playlist_detail_repository_impl.dart';
import 'package:he_music_flutter/features/my/domain/entities/user_playlist_detail_request.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_detail_content.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('fetchDetail delegates to apiClient', () async {
    final fake = _FakeUserPlaylistDetailApiClient();
    final songFake = _FakeUserPlaylistSongApiClient();
    final repo = UserPlaylistDetailRepositoryImpl(fake, songFake);

    final request = UserPlaylistDetailRequest(id: 'pl-1', title: 'My List');
    final result = await repo.fetchDetail(request);

    expect(fake.lastRequestId, 'pl-1');
    expect(result.info.name, 'My Playlist');
  });

  test('updatePlaylist delegates to apiClient', () async {
    final fake = _FakeUserPlaylistDetailApiClient();
    final songFake = _FakeUserPlaylistSongApiClient();
    final repo = UserPlaylistDetailRepositoryImpl(fake, songFake);

    await repo.updatePlaylist(
      id: 'pl-1',
      name: 'New Name',
      cover: 'https://cover.jpg',
      description: 'desc',
    );

    expect(fake.lastUpdateId, 'pl-1');
    expect(fake.lastUpdateName, 'New Name');
  });

  test('deletePlaylist delegates to apiClient', () async {
    final fake = _FakeUserPlaylistDetailApiClient();
    final songFake = _FakeUserPlaylistSongApiClient();
    final repo = UserPlaylistDetailRepositoryImpl(fake, songFake);

    await repo.deletePlaylist('pl-1');

    expect(fake.lastDeleteId, 'pl-1');
  });

  test('addSongs delegates to songApiClient', () async {
    final fake = _FakeUserPlaylistDetailApiClient();
    final songFake = _FakeUserPlaylistSongApiClient();
    final repo = UserPlaylistDetailRepositoryImpl(fake, songFake);

    await repo.addSongs(
      playlistId: 'playlist-1',
      songs: [const IdPlatformInfo(id: 's1', platform: 'qq')],
    );

    expect(songFake.lastAddPlaylistId, 'playlist-1');
    expect(songFake.lastAddSongs, hasLength(1));
  });

  test('removeSongs delegates to songApiClient', () async {
    final fake = _FakeUserPlaylistDetailApiClient();
    final songFake = _FakeUserPlaylistSongApiClient();
    final repo = UserPlaylistDetailRepositoryImpl(fake, songFake);

    await repo.removeSongs(
      playlistId: 'playlist-2',
      songs: [const IdPlatformInfo(id: 's2', platform: 'netease')],
    );

    expect(songFake.lastRemovePlaylistId, 'playlist-2');
    expect(songFake.lastRemoveSongs, hasLength(1));
  });

  test('fetchDetail propagates apiClient error', () async {
    final fake = _ThrowingUserPlaylistDetailApiClient();
    final songFake = _FakeUserPlaylistSongApiClient();
    final repo = UserPlaylistDetailRepositoryImpl(fake, songFake);

    expect(
      () => repo.fetchDetail(UserPlaylistDetailRequest(id: 'pl-1', title: 'x')),
      throwsException,
    );
  });
}

class _FakeUserPlaylistDetailApiClient extends UserPlaylistDetailApiClient {
  _FakeUserPlaylistDetailApiClient() : super(Dio());

  String? lastRequestId;
  String? lastUpdateId;
  String? lastUpdateName;
  String? lastDeleteId;

  @override
  Future<PlaylistDetailContent> fetchDetail(
    UserPlaylistDetailRequest request,
  ) async {
    lastRequestId = request.id;
    return PlaylistDetailContent(
      info: const PlaylistInfo(
        name: 'My Playlist',
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

  @override
  Future<void> updatePlaylist({
    required String id,
    required String name,
    required String cover,
    required String description,
  }) async {
    lastUpdateId = id;
    lastUpdateName = name;
  }

  @override
  Future<void> deletePlaylist(String id) async {
    lastDeleteId = id;
  }
}

class _FakeUserPlaylistSongApiClient extends UserPlaylistSongApiClient {
  _FakeUserPlaylistSongApiClient() : super(Dio());

  String? lastAddPlaylistId;
  List<IdPlatformInfo>? lastAddSongs;
  String? lastRemovePlaylistId;
  List<IdPlatformInfo>? lastRemoveSongs;

  @override
  Future<void> addSongs({
    required String playlistId,
    required List<IdPlatformInfo> songs,
  }) async {
    lastAddPlaylistId = playlistId;
    lastAddSongs = songs;
  }

  @override
  Future<void> removeSongs({
    required String playlistId,
    required List<IdPlatformInfo> songs,
  }) async {
    lastRemovePlaylistId = playlistId;
    lastRemoveSongs = songs;
  }
}

class _ThrowingUserPlaylistDetailApiClient extends UserPlaylistDetailApiClient {
  _ThrowingUserPlaylistDetailApiClient() : super(Dio());

  @override
  Future<PlaylistDetailContent> fetchDetail(
    UserPlaylistDetailRequest request,
  ) => throw Exception('network error');

  @override
  Future<void> updatePlaylist({
    required String id,
    required String name,
    required String cover,
    required String description,
  }) async {}

  @override
  Future<void> deletePlaylist(String id) async {}
}
