import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/artist/data/datasources/artist_detail_api_client.dart';
import 'package:he_music_flutter/features/artist/data/repositories/artist_detail_repository_impl.dart';
import 'package:he_music_flutter/features/artist/domain/entities/artist_detail_content.dart';
import 'package:he_music_flutter/features/artist/domain/entities/artist_detail_page_chunk.dart';
import 'package:he_music_flutter/features/artist/domain/entities/artist_detail_request.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('fetchDetail delegates to apiClient', () async {
    final fake = _FakeArtistDetailApiClient();
    final repo = ArtistDetailRepositoryImpl(fake);

    final request = ArtistDetailRequest(
      id: 'ar1',
      platform: 'netease',
      title: 'Artist',
    );
    final result = await repo.fetchDetail(request);

    expect(fake.lastDetailRequest, request);
    expect(result.info.name, 'Test Artist');
  });

  test('fetchSongs delegates to apiClient', () async {
    final fake = _FakeArtistDetailApiClient();
    final repo = ArtistDetailRepositoryImpl(fake);

    final request = ArtistDetailRequest(
      id: 'ar1',
      platform: 'netease',
      title: 'x',
    );
    final result = await repo.fetchSongs(request);

    expect(fake.lastSongsRequest, request);
    expect(result, hasLength(1));
  });

  test('fetchSongsPage delegates to apiClient', () async {
    final fake = _FakeArtistDetailApiClient();
    final repo = ArtistDetailRepositoryImpl(fake);

    final request = ArtistDetailRequest(
      id: 'ar1',
      platform: 'netease',
      title: 'x',
    );
    final result = await repo.fetchSongsPage(request, pageIndex: 2);

    expect(fake.lastSongsPageIndex, 2);
    expect(result.items, hasLength(1));
    expect(result.hasMore, isFalse);
  });

  test('fetchAlbums delegates to apiClient', () async {
    final fake = _FakeArtistDetailApiClient();
    final repo = ArtistDetailRepositoryImpl(fake);

    final request = ArtistDetailRequest(
      id: 'ar1',
      platform: 'netease',
      title: 'x',
    );
    await repo.fetchAlbums(request);

    expect(fake.lastAlbumsRequest, request);
  });

  test('fetchVideos delegates to apiClient', () async {
    final fake = _FakeArtistDetailApiClient();
    final repo = ArtistDetailRepositoryImpl(fake);

    final request = ArtistDetailRequest(
      id: 'ar1',
      platform: 'netease',
      title: 'x',
    );
    await repo.fetchVideos(request);

    expect(fake.lastVideosRequest, request);
  });

  test('fetchDetail propagates apiClient error', () async {
    final fake = _ThrowingArtistDetailApiClient();
    final repo = ArtistDetailRepositoryImpl(fake);

    expect(
      () => repo.fetchDetail(
        ArtistDetailRequest(id: 'ar1', platform: 'netease', title: 'x'),
      ),
      throwsException,
    );
  });
}

SongInfo _makeSongInfo(String id) => SongInfo(
  name: 'Song $id',
  subtitle: '',
  id: id,
  duration: 180,
  mvId: '',
  album: const SongInfoAlbumInfo(name: '', id: ''),
  artists: const [],
  links: const [],
  platform: 'netease',
  cover: '',
  sublist: const [],
  originalType: 0,
);

class _FakeArtistDetailApiClient extends ArtistDetailApiClient {
  _FakeArtistDetailApiClient() : super(Dio());

  ArtistDetailRequest? lastDetailRequest;
  ArtistDetailRequest? lastSongsRequest;
  int? lastSongsPageIndex;
  ArtistDetailRequest? lastAlbumsRequest;
  ArtistDetailRequest? lastVideosRequest;

  @override
  Future<ArtistDetailContent> fetchDetail(ArtistDetailRequest request) async {
    lastDetailRequest = request;
    return const ArtistDetailContent(
      info: ArtistInfo(
        id: 'ar1',
        name: 'Test Artist',
        cover: '',
        platform: 'netease',
        description: '',
        mvCount: '5',
        songCount: '100',
        albumCount: '10',
        alias: '',
      ),
      songs: [],
    );
  }

  @override
  Future<List<SongInfo>> fetchSongs(ArtistDetailRequest request) async {
    lastSongsRequest = request;
    return [_makeSongInfo('s1')];
  }

  @override
  Future<ArtistDetailPageChunk<SongInfo>> fetchSongsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async {
    lastSongsPageIndex = pageIndex;
    return ArtistDetailPageChunk(
      items: [_makeSongInfo('s1')],
      hasMore: false,
      nextPageIndex: pageIndex + 1,
    );
  }

  @override
  Future<List<AlbumInfo>> fetchAlbums(ArtistDetailRequest request) async {
    lastAlbumsRequest = request;
    return [];
  }

  @override
  Future<ArtistDetailPageChunk<AlbumInfo>> fetchAlbumsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async =>
      const ArtistDetailPageChunk(items: [], hasMore: false, nextPageIndex: 0);

  @override
  Future<List<MvInfo>> fetchVideos(ArtistDetailRequest request) async {
    lastVideosRequest = request;
    return [];
  }

  @override
  Future<ArtistDetailPageChunk<MvInfo>> fetchVideosPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) async =>
      const ArtistDetailPageChunk(items: [], hasMore: false, nextPageIndex: 0);
}

class _ThrowingArtistDetailApiClient extends ArtistDetailApiClient {
  _ThrowingArtistDetailApiClient() : super(Dio());

  @override
  Future<ArtistDetailContent> fetchDetail(ArtistDetailRequest request) =>
      throw Exception('network error');

  @override
  Future<List<SongInfo>> fetchSongs(ArtistDetailRequest request) =>
      throw Exception('error');

  @override
  Future<ArtistDetailPageChunk<SongInfo>> fetchSongsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) => throw Exception('error');

  @override
  Future<List<AlbumInfo>> fetchAlbums(ArtistDetailRequest request) =>
      throw Exception('error');

  @override
  Future<ArtistDetailPageChunk<AlbumInfo>> fetchAlbumsPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) => throw Exception('error');

  @override
  Future<List<MvInfo>> fetchVideos(ArtistDetailRequest request) =>
      throw Exception('error');

  @override
  Future<ArtistDetailPageChunk<MvInfo>> fetchVideosPage(
    ArtistDetailRequest request, {
    required int pageIndex,
  }) => throw Exception('error');
}
