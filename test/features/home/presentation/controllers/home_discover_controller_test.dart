import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_discover_section.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_discover_item.dart';
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

  test('平台数据从错误恢复后应自动重试首页内容', () async {
    final apiClient = _DelayedHomeDiscoverApiClient();
    final container = ProviderContainer(
      overrides: [
        homeDiscoverApiClientProvider.overrideWithValue(apiClient),
        onlinePlatformsProvider.overrideWith(
          _RecoveringOnlinePlatformsController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final homeController = container.read(
      homeDiscoverControllerProvider.notifier,
    );
    await homeController.initialize();

    expect(
      container.read(homeDiscoverControllerProvider).errorMessage,
      isNotNull,
    );
    expect(apiClient.fetchDiscoverCallCount, 0);

    final platformsController =
        container.read(onlinePlatformsProvider.notifier)
            as _RecoveringOnlinePlatformsController;
    platformsController.recover();
    await apiClient.requestStarted.future;
    apiClient.complete();
    await container.pump();

    final recoveredState = container.read(homeDiscoverControllerProvider);
    expect(recoveredState.errorMessage, isNull);
    expect(recoveredState.platforms, hasLength(1));
    expect(recoveredState.selectedPlatformId, 'qq');
    expect(apiClient.fetchDiscoverCallCount, 1);
  });

  test('A-B-A 复用进行中的 A 请求并忽略晚到的 B 数据', () async {
    final apiClient = _ControlledHomeDiscoverApiClient();
    final container = ProviderContainer(
      overrides: [
        homeDiscoverApiClientProvider.overrideWithValue(apiClient),
        onlinePlatformsProvider.overrideWith(_TwoOnlinePlatformsController.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(onlinePlatformsProvider.future);
    final controller = container.read(homeDiscoverControllerProvider.notifier);

    final firstA = controller.initialize();
    await apiClient.requestStarted('a');
    final loadingB = controller.selectPlatform('b');
    final secondA = controller.selectPlatform('a');

    expect(apiClient.callsFor('a'), 1);
    expect(apiClient.callsFor('b'), 1);

    apiClient.complete('a');
    await Future.wait(<Future<void>>[firstA, secondA]);
    apiClient.complete('b');
    await loadingB;

    final state = container.read(homeDiscoverControllerProvider);
    expect(state.selectedPlatformId, 'a');
    expect(state.sections.single.key, 'a');
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

class _RecoveringOnlinePlatformsController extends OnlinePlatformsController {
  static final _platforms = <OnlinePlatform>[
    OnlinePlatform(
      id: 'qq',
      name: 'QQ',
      shortName: 'QQ',
      status: 1,
      featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
    ),
  ];

  var _recovered = false;

  @override
  Future<List<OnlinePlatform>> build() async {
    throw StateError('Unauthorized');
  }

  @override
  Future<List<OnlinePlatform>> ensureLoaded({bool forceRefresh = false}) async {
    if (!_recovered) {
      throw StateError('Unauthorized');
    }
    return _platforms;
  }

  void recover() {
    _recovered = true;
    state = AsyncData(_platforms);
  }
}

class _TwoOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[_platform('a'), _platform('b')];
  }

  OnlinePlatform _platform(String id) {
    return OnlinePlatform(
      id: id,
      name: id.toUpperCase(),
      shortName: id.toUpperCase(),
      status: 1,
      featureSupportFlag: PlatformFeatureSupportFlag.getDiscoverPage,
    );
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

class _ControlledHomeDiscoverApiClient extends HomeDiscoverApiClient {
  _ControlledHomeDiscoverApiClient() : super(Dio());

  final Map<String, int> _calls = <String, int>{};
  final Map<String, Completer<void>> _started = <String, Completer<void>>{};
  final Map<String, Completer<List<HomeDiscoverSection>>> _requests =
      <String, Completer<List<HomeDiscoverSection>>>{};

  int callsFor(String platform) => _calls[platform] ?? 0;

  Future<void> requestStarted(String platform) {
    return (_started[platform] ??= Completer<void>()).future;
  }

  @override
  Future<List<HomeDiscoverSection>> fetchDiscoverSections(String platformId) {
    _calls.update(platformId, (count) => count + 1, ifAbsent: () => 1);
    final started = _started[platformId] ??= Completer<void>();
    if (!started.isCompleted) {
      started.complete();
    }
    return (_requests[platformId] ??= Completer<List<HomeDiscoverSection>>())
        .future;
  }

  void complete(String platform) {
    _requests[platform]!.complete(<HomeDiscoverSection>[
      HomeDiscoverSection(
        key: platform,
        titleKey: platform,
        type: HomeDiscoverItemType.song,
      ),
    ]);
  }
}
