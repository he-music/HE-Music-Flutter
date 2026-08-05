import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_result.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_section.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_state.dart';
import 'package:he_music_flutter/features/home/presentation/providers/home_page_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('默认只加载推荐，首次切入发现后切回不重载', () async {
    final api = _ImmediateHomePageApiClient();
    final container = _container(
      api: api,
      platforms: <OnlinePlatform>[
        _platform('qq', recommend: true, discover: true),
      ],
    );
    addTearDown(container.dispose);
    await container.read(onlinePlatformsProvider.future);
    final controller = container.read(homePageControllerProvider.notifier);

    await controller.initialize();

    expect(api.calls, <String>['recommend|qq|1']);
    expect(
      container.read(homePageControllerProvider).selectedPage,
      HomePageKind.recommend,
    );

    await controller.selectPage(HomePageKind.discover);
    await controller.selectPage(HomePageKind.recommend);

    expect(api.calls, <String>['recommend|qq|1', 'discover|qq|1']);
    expect(
      container.read(homePageControllerProvider).discover.initialized,
      isTrue,
    );
  });

  test('页签切换优先沿用目标页支持的来源平台', () async {
    final api = _ImmediateHomePageApiClient();
    final container = _container(
      api: api,
      platforms: <OnlinePlatform>[
        _platform('a', recommend: true, discover: true),
        _platform('b', recommend: true, discover: true),
      ],
    );
    addTearDown(container.dispose);
    await container.read(onlinePlatformsProvider.future);
    final controller = container.read(homePageControllerProvider.notifier);

    await controller.initialize();
    await controller.selectPlatform('b');
    await controller.selectPage(HomePageKind.discover);

    final state = container.read(homePageControllerProvider);
    expect(state.discover.selectedPlatformId, 'b');
    expect(api.calls.last, 'discover|b|1');
  });

  test('推荐不可用时默认发现且只请求发现', () async {
    final api = _ImmediateHomePageApiClient();
    final container = _container(
      api: api,
      platforms: <OnlinePlatform>[_platform('qq', discover: true)],
    );
    addTearDown(container.dispose);
    await container.read(onlinePlatformsProvider.future);

    await container.read(homePageControllerProvider.notifier).initialize();

    final state = container.read(homePageControllerProvider);
    expect(state.selectedPage, HomePageKind.discover);
    expect(state.availablePages, <HomePageKind>[HomePageKind.discover]);
    expect(api.calls, <String>['discover|qq|1']);
  });

  test('来源平台不受支持时恢复目标页记忆平台', () async {
    final api = _ImmediateHomePageApiClient();
    final container = _container(
      api: api,
      platforms: <OnlinePlatform>[
        _platform('a', recommend: true, discover: true),
        _platform('b', recommend: true),
        _platform('c', discover: true),
      ],
    );
    addTearDown(container.dispose);
    await container.read(onlinePlatformsProvider.future);
    final controller = container.read(homePageControllerProvider.notifier);

    await controller.initialize();
    await controller.selectPage(HomePageKind.discover);
    await controller.selectPlatform('c');
    await controller.selectPage(HomePageKind.recommend);
    await controller.selectPlatform('b');
    await controller.selectPage(HomePageKind.discover);

    final state = container.read(homePageControllerProvider);
    expect(state.discover.selectedPlatformId, 'c');
    expect(api.calls.where((call) => call == 'discover|c|1'), hasLength(1));
  });

  test('推荐平台 A-B-A 复用进行中的 A 请求并忽略晚到 B', () async {
    final api = _ControlledHomePageApiClient();
    final container = _container(
      api: api,
      platforms: <OnlinePlatform>[
        _platform('a', recommend: true),
        _platform('b', recommend: true),
      ],
    );
    addTearDown(container.dispose);
    await container.read(onlinePlatformsProvider.future);
    final controller = container.read(homePageControllerProvider.notifier);

    final firstA = controller.initialize();
    await api.started('recommend|a|1');
    final loadingB = controller.selectPlatform('b');
    await api.started('recommend|b|1');
    final secondA = controller.selectPlatform('a');

    expect(api.callCount('recommend|a|1'), 1);
    api.complete('recommend|a|1', _result('a'));
    await Future.wait(<Future<void>>[firstA, secondA]);
    api.complete('recommend|b|1', _result('b'));
    await loadingB;

    final state = container.read(homePageControllerProvider).recommend;
    expect(state.selectedPlatformId, 'a');
    expect(state.sections.single.title, 'a');
  });

  test('加载更多只提交一次，FEED 保留重复资源并服从 hasMore', () async {
    final duplicate = _song('same');
    final pageOne = HomePageResult(
      sections: <HomePageSection>[_feed('旧标题', duplicate)],
      hasMore: true,
    );
    final pageTwo = HomePageResult(
      sections: <HomePageSection>[_feed('新标题', duplicate)],
      hasMore: false,
    );
    final api = _ControlledHomePageApiClient();
    final container = _container(
      api: api,
      platforms: <OnlinePlatform>[_platform('qq', recommend: true)],
    );
    addTearDown(container.dispose);
    await container.read(onlinePlatformsProvider.future);
    final controller = container.read(homePageControllerProvider.notifier);

    final initialize = controller.initialize();
    await api.started('recommend|qq|1');
    api.complete('recommend|qq|1', pageOne);
    await initialize;
    final firstLoadMore = controller.loadMore();
    final secondLoadMore = controller.loadMore();
    await api.started('recommend|qq|2');
    expect(api.callCount('recommend|qq|2'), 1);
    api.complete('recommend|qq|2', pageTwo);
    await Future.wait(<Future<void>>[firstLoadMore, secondLoadMore]);
    await controller.loadMore();

    final state = container.read(homePageControllerProvider).recommend;
    expect(state.sections.single.title, '旧标题');
    expect(state.sections.single.songs.map((song) => song.id), <String>[
      'same',
      'same',
    ]);
    expect(state.hasMore, isFalse);
    expect(state.nextPageIndex, 3);
    expect(api.callCount('recommend|qq|2'), 1);
  });

  test('加载更多失败保留页码，重试成功后追加一次', () async {
    final api = _RetryHomePageApiClient();
    final container = _container(
      api: api,
      platforms: <OnlinePlatform>[_platform('qq', recommend: true)],
    );
    addTearDown(container.dispose);
    await container.read(onlinePlatformsProvider.future);
    final controller = container.read(homePageControllerProvider.notifier);

    await controller.initialize();
    await controller.loadMore();
    var state = container.read(homePageControllerProvider).recommend;
    expect(state.nextPageIndex, 2);
    expect(state.loadMoreErrorMessage, isNotNull);

    await controller.loadMore();
    state = container.read(homePageControllerProvider).recommend;

    expect(api.pageTwoCalls, 2);
    expect(state.nextPageIndex, 3);
    expect(state.sections, hasLength(2));
    expect(state.loadMoreErrorMessage, isNull);
  });

  test('刷新失败保留旧内容，下一次成功完整替换第一页', () async {
    final api = _RefreshHomePageApiClient();
    final container = _container(
      api: api,
      platforms: <OnlinePlatform>[_platform('qq', recommend: true)],
    );
    addTearDown(container.dispose);
    await container.read(onlinePlatformsProvider.future);
    final controller = container.read(homePageControllerProvider.notifier);

    await controller.initialize();
    final error = await controller.refresh();

    var state = container.read(homePageControllerProvider).recommend;
    expect(error, contains('refresh failed'));
    expect(state.sections.single.title, 'old');
    expect(state.refreshing, isFalse);

    expect(await controller.refresh(), isNull);
    state = container.read(homePageControllerProvider).recommend;
    expect(state.sections.single.title, 'new');
    expect(state.nextPageIndex, 2);
    expect(state.hasMore, isFalse);
  });

  test('刷新使进行中的加载更多失效，旧页不得追加', () async {
    final api = _RefreshDuringLoadMoreApiClient();
    final container = _container(
      api: api,
      platforms: <OnlinePlatform>[_platform('qq', recommend: true)],
    );
    addTearDown(container.dispose);
    await container.read(onlinePlatformsProvider.future);
    final controller = container.read(homePageControllerProvider.notifier);

    await controller.initialize();
    final loadMore = controller.loadMore();
    await api.pageTwoStarted.future;
    await controller.refresh();
    api.pageTwo.complete(_result('stale-page-two'));
    await loadMore;

    final state = container.read(homePageControllerProvider).recommend;
    expect(state.sections.map((section) => section.title), <String>['fresh']);
    expect(state.loadingMore, isFalse);
    expect(state.hasMore, isFalse);
  });
}

ProviderContainer _container({
  required HomePageApiClient api,
  required List<OnlinePlatform> platforms,
}) {
  return ProviderContainer(
    overrides: [
      homePageApiClientProvider.overrideWithValue(api),
      onlinePlatformsProvider.overrideWith(
        () => _FakeOnlinePlatformsController(platforms),
      ),
    ],
  );
}

class _FakeOnlinePlatformsController extends OnlinePlatformsController {
  _FakeOnlinePlatformsController(this.platforms);

  final List<OnlinePlatform> platforms;

  @override
  Future<List<OnlinePlatform>> build() async => platforms;
}

class _ImmediateHomePageApiClient extends HomePageApiClient {
  _ImmediateHomePageApiClient() : super(Dio());

  final List<String> calls = <String>[];

  @override
  Future<HomePageResult> fetchRecommendPage({
    required String platformId,
    required int pageIndex,
  }) async {
    calls.add('recommend|$platformId|$pageIndex');
    return _result('$platformId-$pageIndex', hasMore: pageIndex == 1);
  }

  @override
  Future<HomePageResult> fetchDiscoverPage({required String platformId}) async {
    calls.add('discover|$platformId|1');
    return _result('discover-$platformId');
  }
}

class _ControlledHomePageApiClient extends HomePageApiClient {
  _ControlledHomePageApiClient() : super(Dio());

  final Map<String, int> _calls = <String, int>{};
  final Map<String, Completer<void>> _started = <String, Completer<void>>{};
  final Map<String, Completer<HomePageResult>> _results =
      <String, Completer<HomePageResult>>{};

  int callCount(String key) => _calls[key] ?? 0;
  Future<void> started(String key) =>
      (_started[key] ??= Completer<void>()).future;

  void complete(String key, HomePageResult result) {
    _results[key]!.complete(result);
  }

  @override
  Future<HomePageResult> fetchRecommendPage({
    required String platformId,
    required int pageIndex,
  }) {
    return _request('recommend|$platformId|$pageIndex');
  }

  @override
  Future<HomePageResult> fetchDiscoverPage({required String platformId}) {
    return _request('discover|$platformId|1');
  }

  Future<HomePageResult> _request(String key) {
    _calls.update(key, (count) => count + 1, ifAbsent: () => 1);
    final started = _started[key] ??= Completer<void>();
    if (!started.isCompleted) {
      started.complete();
    }
    return (_results[key] ??= Completer<HomePageResult>()).future;
  }
}

class _RetryHomePageApiClient extends HomePageApiClient {
  _RetryHomePageApiClient() : super(Dio());

  int pageTwoCalls = 0;

  @override
  Future<HomePageResult> fetchRecommendPage({
    required String platformId,
    required int pageIndex,
  }) async {
    if (pageIndex == 1) {
      return _result('first', hasMore: true);
    }
    pageTwoCalls += 1;
    if (pageTwoCalls == 1) {
      throw StateError('load more failed');
    }
    return _result('second');
  }

  @override
  Future<HomePageResult> fetchDiscoverPage({required String platformId}) async {
    return _result('discover');
  }
}

class _RefreshHomePageApiClient extends HomePageApiClient {
  _RefreshHomePageApiClient() : super(Dio());

  int pageOneCalls = 0;

  @override
  Future<HomePageResult> fetchRecommendPage({
    required String platformId,
    required int pageIndex,
  }) async {
    pageOneCalls += 1;
    if (pageOneCalls == 1) {
      return _result('old', hasMore: true);
    }
    if (pageOneCalls == 2) {
      throw StateError('refresh failed');
    }
    return _result('new');
  }

  @override
  Future<HomePageResult> fetchDiscoverPage({required String platformId}) async {
    return _result('discover');
  }
}

class _RefreshDuringLoadMoreApiClient extends HomePageApiClient {
  _RefreshDuringLoadMoreApiClient() : super(Dio());

  final Completer<void> pageTwoStarted = Completer<void>();
  final Completer<HomePageResult> pageTwo = Completer<HomePageResult>();
  int pageOneCalls = 0;

  @override
  Future<HomePageResult> fetchRecommendPage({
    required String platformId,
    required int pageIndex,
  }) {
    if (pageIndex == 2) {
      pageTwoStarted.complete();
      return pageTwo.future;
    }
    pageOneCalls += 1;
    return Future<HomePageResult>.value(
      pageOneCalls == 1 ? _result('old', hasMore: true) : _result('fresh'),
    );
  }

  @override
  Future<HomePageResult> fetchDiscoverPage({required String platformId}) async {
    return _result('discover');
  }
}

OnlinePlatform _platform(
  String id, {
  bool recommend = false,
  bool discover = false,
}) {
  var flags = BigInt.zero;
  if (recommend) flags |= PlatformFeatureSupportFlag.getRecommendPage;
  if (discover) flags |= PlatformFeatureSupportFlag.getDiscoverPage;
  return OnlinePlatform(
    id: id,
    name: id.toUpperCase(),
    shortName: id.toUpperCase(),
    status: 1,
    featureSupportFlag: flags,
  );
}

HomePageResult _result(String title, {bool hasMore = false}) {
  return HomePageResult(
    sections: <HomePageSection>[
      HomePageSection(
        sectionTypeCode: 1,
        sectionType: HomeSectionType.generic,
        resourceType: HomeResourceType.song,
        title: title,
        songs: <SongInfo>[_song(title)],
      ),
    ],
    hasMore: hasMore,
  );
}

HomePageSection _feed(String title, SongInfo song) {
  return HomePageSection(
    sectionTypeCode: 5,
    sectionType: HomeSectionType.feed,
    resourceType: HomeResourceType.song,
    title: title,
    songs: <SongInfo>[song],
  );
}

SongInfo _song(String id) {
  return SongInfo(
    name: id,
    subtitle: '',
    id: id,
    duration: 0,
    mvId: '',
    album: null,
    artists: const <SongInfoArtistInfo>[],
    links: const <LinkInfo>[],
    platform: 'qq',
    cover: '',
  );
}
