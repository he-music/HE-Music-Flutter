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
