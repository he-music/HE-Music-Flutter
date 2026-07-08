import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/my/data/datasources/my_collection_api_client.dart';
import 'package:he_music_flutter/features/my/data/repositories/my_collection_repository_impl.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';

void main() {
  test('fetchFavorites delegates to apiClient', () async {
    final fake = _FakeMyCollectionApiClient();
    final repo = MyCollectionRepositoryImpl(fake);

    final result = await repo.fetchFavorites(MyFavoriteType.songs);

    expect(fake.lastFetchType, MyFavoriteType.songs);
    expect(result, hasLength(1));
    expect(result.first.title, 'Song 1');
  });

  test('removeFavorite delegates to apiClient', () async {
    final fake = _FakeMyCollectionApiClient();
    final repo = MyCollectionRepositoryImpl(fake);

    await repo.removeFavorite(
      type: MyFavoriteType.playlists,
      id: 'p1',
      platform: 'netease',
    );

    expect(fake.lastRemoveType, MyFavoriteType.playlists);
    expect(fake.lastRemoveId, 'p1');
    expect(fake.lastRemovePlatform, 'netease');
  });

  test('fetchFavorites propagates apiClient error', () async {
    final fake = _ThrowingMyCollectionApiClient();
    final repo = MyCollectionRepositoryImpl(fake);

    expect(() => repo.fetchFavorites(MyFavoriteType.songs), throwsException);
  });
}

class _FakeMyCollectionApiClient extends MyCollectionApiClient {
  _FakeMyCollectionApiClient() : super(Dio());

  MyFavoriteType? lastFetchType;
  MyFavoriteType? lastRemoveType;
  String? lastRemoveId;
  String? lastRemovePlatform;

  @override
  Future<List<MyFavoriteItem>> fetchFavorites(MyFavoriteType type) async {
    lastFetchType = type;
    return [
      MyFavoriteItem(
        id: '1',
        platform: 'netease',
        type: type,
        title: 'Song 1',
        subtitle: 'Artist 1',
        coverUrl: 'https://example.com/cover.jpg',
      ),
    ];
  }

  @override
  Future<void> removeFavorite({
    required MyFavoriteType type,
    required String id,
    required String platform,
  }) async {
    lastRemoveType = type;
    lastRemoveId = id;
    lastRemovePlatform = platform;
  }

  @override
  Future<List<MyFavoriteItem>> fetchCreatedPlaylists() async => [];
}

class _ThrowingMyCollectionApiClient extends MyCollectionApiClient {
  _ThrowingMyCollectionApiClient() : super(Dio());

  @override
  Future<List<MyFavoriteItem>> fetchFavorites(MyFavoriteType type) =>
      throw Exception('network error');

  @override
  Future<void> removeFavorite({
    required MyFavoriteType type,
    required String id,
    required String platform,
  }) async {}

  @override
  Future<List<MyFavoriteItem>> fetchCreatedPlaylists() async => [];
}
