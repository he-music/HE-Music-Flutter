import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/my/data/datasources/my_overview_api_client.dart';
import 'package:he_music_flutter/features/my/data/repositories/my_overview_repository_impl.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_profile.dart';

void main() {
  test('fetchOverview aggregates 6 API calls into MyOverview', () async {
    final fake = _FakeMyOverviewApiClient(
      profile: const MyProfile(
        id: 'u1',
        username: 'test',
        nickname: 'Test',
        email: 't@t.com',
        status: 1,
        avatarUrl: 'https://example.com/avatar.png',
      ),
      songCount: 10,
      playlistCount: 5,
      artistCount: 3,
      albumCount: 8,
      createdPlaylistCount: 2,
    );
    final repo = MyOverviewRepositoryImpl(fake);

    final overview = await repo.fetchOverview();

    expect(overview.profile.id, 'u1');
    expect(overview.profile.username, 'test');
    expect(overview.summary.favoriteSongCount, 10);
    expect(overview.summary.favoritePlaylistCount, 5);
    expect(overview.summary.favoriteArtistCount, 3);
    expect(overview.summary.favoriteAlbumCount, 8);
    expect(overview.summary.createdPlaylistCount, 2);
  });

  test('fetchOverview calls all 6 API methods', () async {
    final fake = _FakeMyOverviewApiClient(
      profile: const MyProfile(
        id: '',
        username: '',
        nickname: '',
        email: '',
        status: 0,
        avatarUrl: '',
      ),
      songCount: 0,
      playlistCount: 0,
      artistCount: 0,
      albumCount: 0,
      createdPlaylistCount: 0,
    );
    final repo = MyOverviewRepositoryImpl(fake);

    await repo.fetchOverview();

    expect(fake.profileCalled, isTrue);
    expect(fake.songCountCalled, isTrue);
    expect(fake.playlistCountCalled, isTrue);
    expect(fake.artistCountCalled, isTrue);
    expect(fake.albumCountCalled, isTrue);
    expect(fake.createdPlaylistCountCalled, isTrue);
  });

  test('fetchOverview propagates API exception', () async {
    final fake = _ThrowingMyOverviewApiClient();
    final repo = MyOverviewRepositoryImpl(fake);

    expect(() => repo.fetchOverview(), throwsException);
  });
}

class _FakeMyOverviewApiClient implements MyOverviewApiClient {
  _FakeMyOverviewApiClient({
    required this.profile,
    required this.songCount,
    required this.playlistCount,
    required this.artistCount,
    required this.albumCount,
    required this.createdPlaylistCount,
  });

  final MyProfile profile;
  final int songCount;
  final int playlistCount;
  final int artistCount;
  final int albumCount;
  final int createdPlaylistCount;

  bool profileCalled = false;
  bool songCountCalled = false;
  bool playlistCountCalled = false;
  bool artistCountCalled = false;
  bool albumCountCalled = false;
  bool createdPlaylistCountCalled = false;

  @override
  Future<MyProfile> fetchProfile() async {
    profileCalled = true;
    return profile;
  }

  @override
  Future<int> fetchFavouriteSongCount() async {
    songCountCalled = true;
    return songCount;
  }

  @override
  Future<int> fetchFavouritePlaylistCount() async {
    playlistCountCalled = true;
    return playlistCount;
  }

  @override
  Future<int> fetchFavouriteArtistCount() async {
    artistCountCalled = true;
    return artistCount;
  }

  @override
  Future<int> fetchFavouriteAlbumCount() async {
    albumCountCalled = true;
    return albumCount;
  }

  @override
  Future<int> fetchCreatedPlaylistCount() async {
    createdPlaylistCountCalled = true;
    return createdPlaylistCount;
  }
}

class _ThrowingMyOverviewApiClient implements MyOverviewApiClient {
  @override
  Future<MyProfile> fetchProfile() => throw Exception('network error');

  @override
  Future<int> fetchFavouriteSongCount() async => 0;

  @override
  Future<int> fetchFavouritePlaylistCount() async => 0;

  @override
  Future<int> fetchFavouriteArtistCount() async => 0;

  @override
  Future<int> fetchFavouriteAlbumCount() async => 0;

  @override
  Future<int> fetchCreatedPlaylistCount() async => 0;
}
