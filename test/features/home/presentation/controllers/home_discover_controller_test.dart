import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_discover_section.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_platform.dart';
import 'package:he_music_flutter/features/home/presentation/providers/home_discover_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';

void main() {
  test('发现页内容加载期间应立即暴露已预加载的平台', () async {
    final apiClient = _DelayedHomeDiscoverApiClient();
    final container = ProviderContainer(
      overrides: [
        homeDiscoverApiClientProvider.overrideWithValue(apiClient),
        onlinePlatformsProvider.overrideWith(
          _TestOnlinePlatformsController.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(onlinePlatformsProvider.future);

    final initialize = container
        .read(homeDiscoverControllerProvider.notifier)
        .initialize();
    await apiClient.requestStarted.future;

    final loadingState = container.read(homeDiscoverControllerProvider);
    expect(loadingState.loading, isTrue);
    expect(loadingState.platforms, hasLength(1));
    expect(loadingState.selectedPlatformId, 'qq');
    expect(apiClient.fetchPlatformsCallCount, 0);

    apiClient.complete();
    await initialize;
  });

  test('并发初始化应复用同一个首页加载流程', () async {
    final apiClient = _DelayedHomeDiscoverApiClient();
    final container = ProviderContainer(
      overrides: [
        homeDiscoverApiClientProvider.overrideWithValue(apiClient),
        onlinePlatformsProvider.overrideWith(
          _TestOnlinePlatformsController.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(onlinePlatformsProvider.future);

    final controller = container.read(homeDiscoverControllerProvider.notifier);
    final first = controller.initialize();
    final second = controller.initialize();

    expect(identical(first, second), isTrue);
    await apiClient.requestStarted.future;
    expect(apiClient.fetchDiscoverCallCount, 1);

    apiClient.complete();
    await Future.wait([first, second]);

    expect(apiClient.fetchDiscoverCallCount, 1);
  });
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
      ),
    ];
  }
}

class _DelayedHomeDiscoverApiClient extends HomeDiscoverApiClient {
  _DelayedHomeDiscoverApiClient() : super(Dio());

  final requestStarted = Completer<void>();
  final _response = Completer<List<HomeDiscoverSection>>();
  int fetchDiscoverCallCount = 0;
  int fetchPlatformsCallCount = 0;

  @override
  Future<List<HomeDiscoverSection>> fetchDiscoverSections(String platformId) {
    fetchDiscoverCallCount += 1;
    if (!requestStarted.isCompleted) {
      requestStarted.complete();
    }
    return _response.future;
  }

  @override
  Future<List<HomePlatform>> fetchPlatforms() async {
    fetchPlatformsCallCount += 1;
    return const <HomePlatform>[];
  }

  void complete() {
    _response.complete(const <HomeDiscoverSection>[]);
  }
}
