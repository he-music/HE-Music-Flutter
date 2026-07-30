import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/video/domain/entities/video_plaza_page_result.dart';
import 'package:he_music_flutter/features/video/presentation/providers/video_plaza_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('initialize loads filters and first video page', () async {
    final client = _FakeVideoPlazaApiClient();
    final container = ProviderContainer(
      overrides: [videoPlazaApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container
        .read(videoPlazaControllerProvider.notifier)
        .initialize('qq');
    final state = container.read(videoPlazaControllerProvider);

    expect(client.fetchFiltersCalls, 1);
    expect(client.fetchVideosCalls, 1);
    expect(state.selectedPlatformId, 'qq');
    expect(state.selectedFilters['area'], '');
    expect(state.items.map((item) => item.name), contains('今日 MV'));
    expect(state.pageIndex, 2);
    expect(state.hasMore, true);
  });

  test('loadMore appends videos from next page', () async {
    final client = _FakeVideoPlazaApiClient();
    final container = ProviderContainer(
      overrides: [videoPlazaApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container
        .read(videoPlazaControllerProvider.notifier)
        .initialize('qq');
    await container.read(videoPlazaControllerProvider.notifier).loadMore();
    final state = container.read(videoPlazaControllerProvider);

    expect(client.fetchVideosCalls, 2);
    expect(state.items.map((item) => item.name), <String>['今日 MV', '继续播放']);
    expect(state.pageIndex, 3);
    expect(state.hasMore, false);
  });

  test('selectFilter accepts empty string option values', () async {
    final client = _FakeVideoPlazaApiClient();
    final container = ProviderContainer(
      overrides: [videoPlazaApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container
        .read(videoPlazaControllerProvider.notifier)
        .initialize('qq');
    await container
        .read(videoPlazaControllerProvider.notifier)
        .selectFilter(groupId: 'area', value: 'cn');
    await container
        .read(videoPlazaControllerProvider.notifier)
        .selectFilter(groupId: 'area', value: '');
    final state = container.read(videoPlazaControllerProvider);

    expect(state.selectedFilters['area'], '');
    expect(client.fetchVideosCalls, 3);
    expect(client.lastFilters['area'], '');
  });

  test('A-B-A reuses pending A requests and keeps A videos', () async {
    final client = _ControlledVideoPlazaApiClient();
    final container = ProviderContainer(
      overrides: [videoPlazaApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    final controller = container.read(videoPlazaControllerProvider.notifier);

    final firstA = controller.selectPlatform('a');
    final loadingB = controller.selectPlatform('b');
    final secondA = controller.selectPlatform('a');

    expect(client.filterCallsFor('a'), 1);
    expect(client.filterCallsFor('b'), 1);

    client.completeFilters('a');
    await client.firstPageStarted('a');
    expect(client.firstPageCallsFor('a'), 1);
    client.completeFirstPage('a');
    await Future.wait(<Future<void>>[firstA, secondA]);

    client.completeFilters('b');
    await loadingB;

    final state = container.read(videoPlazaControllerProvider);
    expect(state.selectedPlatformId, 'a');
    expect(state.items.single.platform, 'a');
    expect(client.firstPageCallsFor('b'), 0);
  });
}

class _FakeVideoPlazaApiClient extends VideoPlazaApiClient {
  _FakeVideoPlazaApiClient() : super(Dio());

  int fetchFiltersCalls = 0;
  int fetchVideosCalls = 0;
  Map<String, String> lastFilters = const <String, String>{};

  @override
  Future<List<FilterInfo>> fetchFilters({required String platform}) async {
    fetchFiltersCalls += 1;
    return const <FilterInfo>[
      FilterInfo(
        id: 'area',
        platform: 'qq',
        options: <FilterOptionInfo>[
          FilterOptionInfo(value: 'all', label: '全部'),
          FilterOptionInfo(value: 'cn', label: '华语'),
          FilterOptionInfo(value: '', label: '全部（后端空值）'),
        ],
      ),
    ];
  }

  @override
  Future<VideoPlazaPageResult> fetchVideos({
    required String platform,
    required Map<String, String> filters,
    int pageIndex = 1,
    int pageSize = 50,
  }) async {
    fetchVideosCalls += 1;
    lastFilters = Map<String, String>.of(filters);
    if (pageIndex == 1) {
      return VideoPlazaPageResult(
        list: <MvInfo>[
          MvInfo(
            platform: platform,
            links: const <LinkInfo>[],
            id: 'mv-1',
            name: '今日 MV',
            cover: '',
            type: 0,
            playCount: '10',
            creator: '测试作者',
            duration: 120,
            description: '',
          ),
        ],
        hasMore: true,
      );
    }
    return VideoPlazaPageResult(
      list: <MvInfo>[
        MvInfo(
          platform: platform,
          links: const <LinkInfo>[],
          id: 'mv-2',
          name: '继续播放',
          cover: '',
          type: 0,
          playCount: '20',
          creator: '测试作者',
          duration: 150,
          description: '',
        ),
      ],
      hasMore: false,
    );
  }
}

class _ControlledVideoPlazaApiClient extends VideoPlazaApiClient {
  _ControlledVideoPlazaApiClient() : super(Dio());

  final Map<String, int> _filterCalls = <String, int>{};
  final Map<String, int> _firstPageCalls = <String, int>{};
  final Map<String, Completer<List<FilterInfo>>> _filterRequests =
      <String, Completer<List<FilterInfo>>>{};
  final Map<String, Completer<VideoPlazaPageResult>> _firstPageRequests =
      <String, Completer<VideoPlazaPageResult>>{};
  final Map<String, Completer<void>> _firstPageStarted =
      <String, Completer<void>>{};

  int filterCallsFor(String platform) => _filterCalls[platform] ?? 0;

  int firstPageCallsFor(String platform) => _firstPageCalls[platform] ?? 0;

  Future<void> firstPageStarted(String platform) {
    return (_firstPageStarted[platform] ??= Completer<void>()).future;
  }

  @override
  Future<List<FilterInfo>> fetchFilters({required String platform}) {
    _filterCalls.update(platform, (count) => count + 1, ifAbsent: () => 1);
    return (_filterRequests[platform] ??= Completer<List<FilterInfo>>()).future;
  }

  @override
  Future<VideoPlazaPageResult> fetchVideos({
    required String platform,
    required Map<String, String> filters,
    int pageIndex = 1,
    int pageSize = 50,
  }) {
    _firstPageCalls.update(platform, (count) => count + 1, ifAbsent: () => 1);
    final started = _firstPageStarted[platform] ??= Completer<void>();
    if (!started.isCompleted) {
      started.complete();
    }
    return (_firstPageRequests[platform] ??= Completer<VideoPlazaPageResult>())
        .future;
  }

  void completeFilters(String platform) {
    _filterRequests[platform]!.complete(<FilterInfo>[
      FilterInfo(
        id: 'area',
        platform: platform,
        options: <FilterOptionInfo>[
          FilterOptionInfo(value: 'all', label: '$platform-all'),
        ],
      ),
    ]);
  }

  void completeFirstPage(String platform) {
    _firstPageRequests[platform]!.complete(
      VideoPlazaPageResult(
        list: <MvInfo>[
          MvInfo(
            platform: platform,
            links: const <LinkInfo>[],
            id: '$platform-video',
            name: '$platform-video',
            cover: '',
            type: 0,
            playCount: '1',
            creator: '',
            duration: 120,
            description: '',
          ),
        ],
        hasMore: false,
      ),
    );
  }
}
