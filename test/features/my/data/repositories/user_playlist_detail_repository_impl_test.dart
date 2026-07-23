import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/my/data/datasources/user_playlist_detail_api_client.dart';
import 'package:he_music_flutter/features/my/data/datasources/user_playlist_song_api_client.dart';
import 'package:he_music_flutter/features/my/data/repositories/user_playlist_detail_repository_impl.dart';
import 'package:he_music_flutter/features/my/domain/entities/user_playlist_detail_request.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('fetchInfo delegates to apiClient', () async {
    final fake = _FakeUserPlaylistDetailApiClient();
    final songFake = _FakeUserPlaylistSongApiClient();
    final repo = UserPlaylistDetailRepositoryImpl(fake, songFake);

    final request = UserPlaylistDetailRequest(id: 'pl-1', title: 'My List');
    final result = await repo.fetchInfo(request);

    expect(fake.lastRequestId, 'pl-1');
    expect(result.name, 'My Playlist');
  });

  test('fetchSongs delegates to apiClient', () async {
    final fake = _FakeUserPlaylistDetailApiClient();
    final songFake = _FakeUserPlaylistSongApiClient();
    final repo = UserPlaylistDetailRepositoryImpl(fake, songFake);
    final request = UserPlaylistDetailRequest(id: 'pl-1', title: 'My List');

    final result = await repo.fetchSongs(request);

    expect(fake.lastSongsRequestId, 'pl-1');
    expect(result, hasLength(1));
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

  test('fetchInfo propagates apiClient error', () async {
    final fake = _ThrowingUserPlaylistDetailApiClient();
    final songFake = _FakeUserPlaylistSongApiClient();
    final repo = UserPlaylistDetailRepositoryImpl(fake, songFake);

    expect(
      () => repo.fetchInfo(UserPlaylistDetailRequest(id: 'pl-1', title: 'x')),
      throwsException,
    );
  });
}

class _FakeUserPlaylistDetailApiClient extends UserPlaylistDetailApiClient {
  _FakeUserPlaylistDetailApiClient() : super(Dio());

  String? lastRequestId;
  String? lastSongsRequestId;
  String? lastUpdateId;
  String? lastUpdateName;
  String? lastDeleteId;

  @override
  Future<PlaylistInfo> fetchInfo(UserPlaylistDetailRequest request) async {
    lastRequestId = request.id;
    return const PlaylistInfo(
      name: 'My Playlist',
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
  Future<List<SongInfo>> fetchSongs(UserPlaylistDetailRequest request) async {
    lastSongsRequestId = request.id;
    return <SongInfo>[_song()];
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
  Future<PlaylistInfo> fetchInfo(UserPlaylistDetailRequest request) {
    throw Exception('network error');
  }

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
    platform: 'qq',
    cover: '',
    sublist: <SongInfo>[],
    originalType: 0,
  );
}
