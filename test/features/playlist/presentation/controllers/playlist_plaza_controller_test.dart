import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_category_group.dart';
import 'package:he_music_flutter/features/playlist/domain/entities/playlist_plaza_page_result.dart';
import 'package:he_music_flutter/features/playlist/presentation/providers/playlist_plaza_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('initialize loads first category and first page playlists', () async {
    final client = _FakePlaylistPlazaApiClient();
    final container = ProviderContainer(
      overrides: [playlistPlazaApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container
        .read(playlistPlazaControllerProvider.notifier)
        .initialize('qq');
    final state = container.read(playlistPlazaControllerProvider);

    expect(client.fetchCategoriesCalls, 1);
    expect(client.fetchCategoryPlaylistsCalls, 1);
    expect(state.selectedPlatformId, 'qq');
    expect(state.selectedCategoryId, 'pop');
    expect(state.playlists.map((item) => item.name), contains('流行精选'));
    expect(state.pageIndex, 2);
    expect(state.hasMore, true);
  });

  test('loadMore appends playlists from next page', () async {
    final client = _FakePlaylistPlazaApiClient();
    final container = ProviderContainer(
      overrides: [playlistPlazaApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container
        .read(playlistPlazaControllerProvider.notifier)
        .initialize('qq');
    await container.read(playlistPlazaControllerProvider.notifier).loadMore();
    final state = container.read(playlistPlazaControllerProvider);

    expect(client.fetchCategoryPlaylistsCalls, 2);
    expect(state.playlists.map((item) => item.name), <String>['流行精选', '继续推荐']);
    expect(state.pageIndex, 3);
    expect(state.hasMore, false);
    expect(state.lastId, 'page-2');
  });

  test('A-B-A reuses pending A requests and keeps A content', () async {
    final client = _ControlledPlaylistPlazaApiClient();
    final container = ProviderContainer(
      overrides: [playlistPlazaApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    final controller = container.read(playlistPlazaControllerProvider.notifier);

    final firstA = controller.selectPlatform('a');
    final loadingB = controller.selectPlatform('b');
    final secondA = controller.selectPlatform('a');

    expect(client.categoryCallsFor('a'), 1);
    expect(client.categoryCallsFor('b'), 1);

    client.completeCategories('a');
    await client.firstPageStarted('a');
    expect(client.firstPageCallsFor('a'), 1);
    client.completeFirstPage('a');
    await Future.wait(<Future<void>>[firstA, secondA]);

    client.completeCategories('b');
    await loadingB;

    final state = container.read(playlistPlazaControllerProvider);
    expect(state.selectedPlatformId, 'a');
    expect(state.selectedCategoryId, 'a-category');
    expect(state.playlists.single.platform, 'a');
    expect(client.firstPageCallsFor('b'), 0);
  });
}

class _FakePlaylistPlazaApiClient extends PlaylistPlazaApiClient {
  _FakePlaylistPlazaApiClient() : super(Dio());

  int fetchCategoriesCalls = 0;
  int fetchCategoryPlaylistsCalls = 0;

  @override
  Future<List<PlaylistCategoryGroup>> fetchCategories({
    required String platform,
  }) async {
    fetchCategoriesCalls += 1;
    return <PlaylistCategoryGroup>[
      PlaylistCategoryGroup(
        name: '推荐',
        categories: <CategoryInfo>[
          CategoryInfo(name: '流行', id: 'pop', platform: platform),
          CategoryInfo(name: '摇滚', id: 'rock', platform: platform),
        ],
      ),
    ];
  }

  @override
  Future<PlaylistPlazaPageResult> fetchCategoryPlaylists({
    required String platform,
    required String categoryId,
    int pageIndex = 1,
    int pageSize = 30,
    String? lastId,
  }) async {
    fetchCategoryPlaylistsCalls += 1;
    if (pageIndex == 1) {
      return PlaylistPlazaPageResult(
        list: <PlaylistInfo>[
          PlaylistInfo(
            name: '流行精选',
            id: 'playlist-1',
            cover: '',
            creator: '测试账号',
            songCount: '10',
            playCount: '100',
            platform: platform,
            description: '',
            songs: const <SongInfo>[],
            categories: <CategoryInfo>[
              CategoryInfo(name: '流行', id: categoryId, platform: platform),
            ],
          ),
        ],
        hasMore: true,
        lastId: 'page-1',
      );
    }
    return PlaylistPlazaPageResult(
      list: <PlaylistInfo>[
        PlaylistInfo(
          name: '继续推荐',
          id: 'playlist-2',
          cover: '',
          creator: '测试账号',
          songCount: '12',
          playCount: '200',
          platform: platform,
          description: '',
          songs: const <SongInfo>[],
          categories: <CategoryInfo>[
            CategoryInfo(name: '流行', id: categoryId, platform: platform),
          ],
        ),
      ],
      hasMore: false,
      lastId: 'page-2',
    );
  }
}

class _ControlledPlaylistPlazaApiClient extends PlaylistPlazaApiClient {
  _ControlledPlaylistPlazaApiClient() : super(Dio());

  final Map<String, int> _categoryCalls = <String, int>{};
  final Map<String, int> _firstPageCalls = <String, int>{};
  final Map<String, Completer<List<PlaylistCategoryGroup>>> _categoryRequests =
      <String, Completer<List<PlaylistCategoryGroup>>>{};
  final Map<String, Completer<PlaylistPlazaPageResult>> _firstPageRequests =
      <String, Completer<PlaylistPlazaPageResult>>{};
  final Map<String, Completer<void>> _firstPageStarted =
      <String, Completer<void>>{};

  int categoryCallsFor(String platform) => _categoryCalls[platform] ?? 0;

  int firstPageCallsFor(String platform) => _firstPageCalls[platform] ?? 0;

  Future<void> firstPageStarted(String platform) {
    return (_firstPageStarted[platform] ??= Completer<void>()).future;
  }

  @override
  Future<List<PlaylistCategoryGroup>> fetchCategories({
    required String platform,
  }) {
    _categoryCalls.update(platform, (count) => count + 1, ifAbsent: () => 1);
    return (_categoryRequests[platform] ??=
            Completer<List<PlaylistCategoryGroup>>())
        .future;
  }

  @override
  Future<PlaylistPlazaPageResult> fetchCategoryPlaylists({
    required String platform,
    required String categoryId,
    int pageIndex = 1,
    int pageSize = 30,
    String? lastId,
  }) {
    _firstPageCalls.update(platform, (count) => count + 1, ifAbsent: () => 1);
    final started = _firstPageStarted[platform] ??= Completer<void>();
    if (!started.isCompleted) {
      started.complete();
    }
    return (_firstPageRequests[platform] ??=
            Completer<PlaylistPlazaPageResult>())
        .future;
  }

  void completeCategories(String platform) {
    _categoryRequests[platform]!.complete(<PlaylistCategoryGroup>[
      PlaylistCategoryGroup(
        name: '$platform-group',
        categories: <CategoryInfo>[
          CategoryInfo(
            name: '$platform-category',
            id: '$platform-category',
            platform: platform,
          ),
        ],
      ),
    ]);
  }

  void completeFirstPage(String platform) {
    _firstPageRequests[platform]!.complete(
      PlaylistPlazaPageResult(
        list: <PlaylistInfo>[
          PlaylistInfo(
            name: '$platform-playlist',
            id: '$platform-playlist',
            cover: '',
            creator: '',
            songCount: '1',
            playCount: '1',
            platform: platform,
            description: '',
            songs: const <SongInfo>[],
          ),
        ],
        hasMore: false,
        lastId: '',
      ),
    );
  }
}
