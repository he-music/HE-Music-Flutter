import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/ranking/data/datasources/ranking_api_client.dart';
import 'package:he_music_flutter/features/ranking/data/repositories/ranking_repository_impl.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_detail.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_group.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_info.dart';

void main() {
  test('fetchRankingGroups delegates to apiClient', () async {
    final fake = _FakeRankingApiClient();
    final repo = RankingRepositoryImpl(fake);

    final result = await repo.fetchRankingGroups(platform: 'netease');

    expect(fake.lastGroupsPlatform, 'netease');
    expect(result, hasLength(1));
    expect(result.first.name, 'Hot');
  });

  test('fetchRankingDetail delegates to apiClient', () async {
    final fake = _FakeRankingApiClient();
    final repo = RankingRepositoryImpl(fake);

    final result = await repo.fetchRankingDetail(
      id: 'r-1',
      platform: 'qq',
      pageIndex: 2,
      pageSize: 50,
    );

    expect(fake.lastDetailId, 'r-1');
    expect(fake.lastDetailPlatform, 'qq');
    expect(fake.lastDetailPageIndex, 2);
    expect(fake.lastDetailPageSize, 50);
    expect(result.description, 'desc');
  });

  test('fetchRankingGroups propagates apiClient error', () async {
    final fake = _ThrowingRankingApiClient();
    final repo = RankingRepositoryImpl(fake);

    expect(() => repo.fetchRankingGroups(platform: 'netease'), throwsException);
  });
}

class _FakeRankingApiClient extends RankingApiClient {
  _FakeRankingApiClient() : super(Dio());

  String? lastGroupsPlatform;
  String? lastDetailId;
  String? lastDetailPlatform;
  int? lastDetailPageIndex;
  int? lastDetailPageSize;

  @override
  Future<List<RankingGroup>> fetchRankingGroups({
    required String platform,
  }) async {
    lastGroupsPlatform = platform;
    return [
      RankingGroup(
        name: 'Hot',
        rankings: [
          const RankingInfo(
            id: 'r1',
            platform: 'netease',
            name: 'Hot',
            coverUrl: '',
            previewSongs: [],
          ),
        ],
      ),
    ];
  }

  @override
  Future<RankingDetail> fetchRankingDetail({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 100,
    String? lastId,
  }) async {
    lastDetailId = id;
    lastDetailPlatform = platform;
    lastDetailPageIndex = pageIndex;
    lastDetailPageSize = pageSize;
    return const RankingDetail(
      info: RankingInfo(
        id: 'r1',
        platform: 'qq',
        name: 'Hot',
        coverUrl: '',
        previewSongs: [],
      ),
      songs: [],
      hasMore: false,
      lastId: '',
      totalCount: 0,
      description: 'desc',
    );
  }
}

class _ThrowingRankingApiClient extends RankingApiClient {
  _ThrowingRankingApiClient() : super(Dio());

  @override
  Future<List<RankingGroup>> fetchRankingGroups({required String platform}) =>
      throw Exception('network error');

  @override
  Future<RankingDetail> fetchRankingDetail({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 100,
    String? lastId,
  }) => throw Exception('network error');
}
