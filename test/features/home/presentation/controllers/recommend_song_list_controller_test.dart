import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/home/domain/entities/recommend_song_list_info.dart';
import 'package:he_music_flutter/features/home/domain/entities/recommend_song_list_request.dart';
import 'package:he_music_flutter/features/home/presentation/providers/home_page_providers.dart';

void main() {
  test('不同详情 key 使用独立状态', () async {
    final apiClient = _ControlledHomePageApiClient();
    final container = ProviderContainer(
      overrides: [homePageApiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
    const requestA = RecommendSongListRequest(id: 'a', platform: 'qq');
    const requestB = RecommendSongListRequest(id: 'b', platform: 'qq');
    final providerA = recommendSongListControllerProvider(requestA.cacheKey);
    final providerB = recommendSongListControllerProvider(requestB.cacheKey);
    final subscriptionA = container.listen(providerA, (_, _) {});
    final subscriptionB = container.listen(providerB, (_, _) {});
    addTearDown(subscriptionA.close);
    addTearDown(subscriptionB.close);

    final loadA = container.read(providerA.notifier).initialize(requestA);
    final loadB = container.read(providerB.notifier).initialize(requestB);
    apiClient.complete(requestB, title: '集合 B');
    await loadB;
    apiClient.complete(requestA, title: '集合 A');
    await loadA;

    expect(container.read(providerA).info?.title, '集合 A');
    expect(container.read(providerB).info?.title, '集合 B');
  });

  test('retry 后迟到的旧响应不能覆盖新详情', () async {
    final apiClient = _ControlledHomePageApiClient();
    final container = ProviderContainer(
      overrides: [homePageApiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
    const request = RecommendSongListRequest(id: 'daily', platform: 'qq');
    final provider = recommendSongListControllerProvider(request.cacheKey);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    final firstLoad = container.read(provider.notifier).initialize(request);
    final retry = container.read(provider.notifier).retry(request);
    apiClient.complete(request, title: '新响应', callIndex: 1);
    await retry;
    apiClient.complete(request, title: '旧响应', callIndex: 0);
    await firstLoad;

    expect(container.read(provider).info?.title, '新响应');
    expect(container.read(provider).errorMessage, isNull);
  });

  test('失败后 retry 可重新加载', () async {
    final apiClient = _ControlledHomePageApiClient();
    final container = ProviderContainer(
      overrides: [homePageApiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
    const request = RecommendSongListRequest(id: 'daily', platform: 'qq');
    final provider = recommendSongListControllerProvider(request.cacheKey);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    final firstLoad = container.read(provider.notifier).initialize(request);
    apiClient.fail(request, StateError('load failed'));
    await firstLoad;
    expect(container.read(provider).errorMessage, contains('load failed'));

    final retry = container.read(provider.notifier).retry(request);
    apiClient.complete(request, title: '恢复成功', callIndex: 1);
    await retry;

    expect(container.read(provider).info?.title, '恢复成功');
    expect(container.read(provider).errorMessage, isNull);
  });
}

class _ControlledHomePageApiClient extends HomePageApiClient {
  _ControlledHomePageApiClient() : super(Dio());

  final Map<String, List<Completer<RecommendSongListInfo>>> _requests = {};

  @override
  Future<RecommendSongListInfo> fetchRecommendSongList(
    RecommendSongListRequest request,
  ) {
    final completer = Completer<RecommendSongListInfo>();
    _requests.putIfAbsent(request.cacheKey, () => []).add(completer);
    return completer.future;
  }

  void complete(
    RecommendSongListRequest request, {
    required String title,
    int callIndex = 0,
  }) {
    _requests[request.cacheKey]![callIndex].complete(
      RecommendSongListInfo(
        id: request.id,
        title: title,
        cover: '',
        description: '',
        songs: const [],
      ),
    );
  }

  void fail(
    RecommendSongListRequest request,
    Object error, {
    int callIndex = 0,
  }) {
    _requests[request.cacheKey]![callIndex].completeError(error);
  }
}
