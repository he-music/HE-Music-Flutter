import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/video/data/datasources/video_detail_api_client.dart';
import 'package:he_music_flutter/features/video/data/repositories/video_detail_repository_impl.dart';
import 'package:he_music_flutter/features/video/domain/entities/video_detail_content.dart';
import 'package:he_music_flutter/features/video/domain/entities/video_detail_request.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('fetchDetail delegates to apiClient', () async {
    final fake = _FakeVideoDetailApiClient();
    final repo = VideoDetailRepositoryImpl(fake);

    final request = VideoDetailRequest(
      id: 'v1',
      platform: 'netease',
      title: 'MV',
    );
    final result = await repo.fetchDetail(request);

    expect(fake.lastRequest, request);
    expect(result.info.name, 'Test MV');
  });

  test('fetchDetail propagates apiClient error', () async {
    final fake = _ThrowingVideoDetailApiClient();
    final repo = VideoDetailRepositoryImpl(fake);

    expect(
      () => repo.fetchDetail(
        VideoDetailRequest(id: 'v1', platform: 'netease', title: 'x'),
      ),
      throwsException,
    );
  });
}

class _FakeVideoDetailApiClient extends VideoDetailApiClient {
  _FakeVideoDetailApiClient() : super(Dio());

  VideoDetailRequest? lastRequest;

  @override
  Future<VideoDetailContent> fetchDetail(VideoDetailRequest request) async {
    lastRequest = request;
    return const VideoDetailContent(
      info: MvInfo(
        platform: 'netease',
        links: [],
        id: 'v1',
        name: 'Test MV',
        cover: '',
        type: 0,
        playCount: '1000',
        creator: 'Artist',
        duration: 240,
        description: '',
      ),
      links: [],
    );
  }
}

class _ThrowingVideoDetailApiClient extends VideoDetailApiClient {
  _ThrowingVideoDetailApiClient() : super(Dio());

  @override
  Future<VideoDetailContent> fetchDetail(VideoDetailRequest request) =>
      throw Exception('network error');
}
