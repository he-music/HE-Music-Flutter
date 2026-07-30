import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/in_flight_request_cache.dart';
import '../../data/providers/playlist_plaza_providers.dart';
import '../../domain/entities/playlist_category_group.dart';
import '../../domain/entities/playlist_plaza_state.dart';
import '../../domain/entities/playlist_plaza_page_result.dart';
import '../providers/playlist_plaza_providers.dart';

class PlaylistPlazaController extends Notifier<PlaylistPlazaState> {
  final Map<String, List<PlaylistCategoryGroup>> _categoryCache =
      <String, List<PlaylistCategoryGroup>>{};
  final Map<String, String> _selectedCategoryCache = <String, String>{};
  final InFlightRequestCache<String, List<PlaylistCategoryGroup>>
  _categoryRequests =
      InFlightRequestCache<String, List<PlaylistCategoryGroup>>();
  final InFlightRequestCache<
    ({String platformId, String categoryId, int pageIndex, String lastId}),
    PlaylistPlazaPageResult
  >
  _pageRequests =
      InFlightRequestCache<
        ({String platformId, String categoryId, int pageIndex, String lastId}),
        PlaylistPlazaPageResult
      >();
  int _requestVersion = 0;

  @override
  PlaylistPlazaState build() {
    return PlaylistPlazaState.initial;
  }

  Future<void> initialize(String platformId) async {
    final currentPlatform = state.selectedPlatformId?.trim() ?? '';
    if (currentPlatform == platformId.trim() &&
        state.categoryGroups.isNotEmpty &&
        state.selectedCategoryId != null) {
      return;
    }
    await selectPlatform(platformId);
  }

  Future<void> selectPlatform(String platformId) async {
    final normalizedPlatformId = platformId.trim();
    if (normalizedPlatformId.isEmpty) {
      return;
    }
    final requestVersion = ++_requestVersion;
    state = state.copyWith(
      selectedPlatformId: normalizedPlatformId,
      categoriesLoading: true,
      playlistsLoading: true,
      loadingMore: false,
      categoryGroups: const <PlaylistCategoryGroup>[],
      clearSelectedCategory: true,
      playlists: const <PlaylistInfo>[],
      hasMore: false,
      pageIndex: 1,
      lastId: '',
      clearCategoriesError: true,
      clearPlaylistsError: true,
    );
    try {
      final groups = await _loadCategories(normalizedPlatformId);
      if (requestVersion != _requestVersion) {
        return;
      }
      final selectedCategoryId = _resolveCategoryId(
        platformId: normalizedPlatformId,
        groups: groups,
      );
      state = state.copyWith(
        categoriesLoading: false,
        categoryGroups: groups,
        selectedCategoryId: selectedCategoryId,
      );
      if (selectedCategoryId == null) {
        state = state.copyWith(
          playlistsLoading: false,
          playlists: const <PlaylistInfo>[],
          hasMore: false,
        );
        return;
      }
      _selectedCategoryCache[normalizedPlatformId] = selectedCategoryId;
      await _loadFirstPage(
        platformId: normalizedPlatformId,
        categoryId: selectedCategoryId,
        requestVersion: requestVersion,
      );
    } catch (error) {
      if (requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(
        categoriesLoading: false,
        playlistsLoading: false,
        categoriesErrorMessage: '$error',
        playlistsErrorMessage: '$error',
      );
    }
  }

  Future<void> selectCategory(String categoryId) async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    final normalizedCategoryId = categoryId.trim();
    if (platformId.isEmpty || normalizedCategoryId.isEmpty) {
      return;
    }
    if (normalizedCategoryId == state.selectedCategoryId &&
        state.playlists.isNotEmpty) {
      return;
    }
    final requestVersion = ++_requestVersion;
    _selectedCategoryCache[platformId] = normalizedCategoryId;
    state = state.copyWith(
      selectedCategoryId: normalizedCategoryId,
      playlistsLoading: true,
      loadingMore: false,
      playlists: const <PlaylistInfo>[],
      hasMore: false,
      pageIndex: 1,
      lastId: '',
      clearPlaylistsError: true,
    );
    try {
      await _loadFirstPage(
        platformId: platformId,
        categoryId: normalizedCategoryId,
        requestVersion: requestVersion,
      );
    } catch (error) {
      if (requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(
        playlistsLoading: false,
        playlistsErrorMessage: '$error',
      );
    }
  }

  Future<void> retry() async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    final categoryId = state.selectedCategoryId?.trim() ?? '';
    if (platformId.isEmpty) {
      return;
    }
    if (state.categoryGroups.isEmpty || state.categoriesErrorMessage != null) {
      await selectPlatform(platformId);
      return;
    }
    if (categoryId.isEmpty) {
      await selectPlatform(platformId);
      return;
    }
    await selectCategory(categoryId);
  }

  Future<void> loadMore() async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    final categoryId = state.selectedCategoryId?.trim() ?? '';
    if (platformId.isEmpty ||
        categoryId.isEmpty ||
        state.loadingMore ||
        state.playlistsLoading ||
        !state.hasMore) {
      return;
    }
    final requestVersion = _requestVersion;
    state = state.copyWith(loadingMore: true, clearPlaylistsError: true);
    try {
      final currentPageIndex = state.pageIndex;
      final currentPlaylists = state.playlists;
      final currentLastId = state.lastId;
      final result = await _pageRequests.run(
        (
          platformId: platformId,
          categoryId: categoryId,
          pageIndex: currentPageIndex,
          lastId: currentLastId,
        ),
        () => _apiClient.fetchCategoryPlaylists(
          platform: platformId,
          categoryId: categoryId,
          pageIndex: currentPageIndex,
          lastId: currentLastId,
        ),
      );
      if (requestVersion != _requestVersion) {
        return;
      }
      final nextPlaylists = <PlaylistInfo>[...currentPlaylists, ...result.list];
      final nextPageIndex = currentPageIndex + 1;
      state = state.copyWith(
        loadingMore: false,
        playlists: nextPlaylists,
        hasMore: result.hasMore,
        lastId: result.lastId,
        pageIndex: nextPageIndex,
      );
    } catch (error) {
      if (requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(
        loadingMore: false,
        playlistsErrorMessage: '$error',
      );
    }
  }

  Future<List<PlaylistCategoryGroup>> _loadCategories(String platformId) async {
    final cached = _categoryCache[platformId];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return _categoryRequests.run(platformId, () async {
      final groups = await _apiClient.fetchCategories(platform: platformId);
      _categoryCache[platformId] = groups;
      return groups;
    });
  }

  Future<void> _loadFirstPage({
    required String platformId,
    required String categoryId,
    required int requestVersion,
  }) async {
    final result = await _pageRequests.run(
      (
        platformId: platformId,
        categoryId: categoryId,
        pageIndex: 1,
        lastId: '',
      ),
      () => _apiClient.fetchCategoryPlaylists(
        platform: platformId,
        categoryId: categoryId,
        pageIndex: 1,
      ),
    );
    if (requestVersion != _requestVersion) {
      return;
    }
    state = state.copyWith(
      playlistsLoading: false,
      playlists: result.list,
      hasMore: result.hasMore,
      lastId: result.lastId,
      pageIndex: 2,
      clearPlaylistsError: true,
    );
  }

  String? _resolveCategoryId({
    required String platformId,
    required List<PlaylistCategoryGroup> groups,
  }) {
    final cachedCategoryId = _selectedCategoryCache[platformId]?.trim() ?? '';
    if (cachedCategoryId.isNotEmpty) {
      for (final group in groups) {
        for (final category in group.categories) {
          if (category.id.trim() == cachedCategoryId) {
            return cachedCategoryId;
          }
        }
      }
    }
    for (final group in groups) {
      for (final category in group.categories) {
        final id = category.id.trim();
        if (id.isNotEmpty) {
          return id;
        }
      }
    }
    return null;
  }

  PlaylistPlazaApiClient get _apiClient {
    return ref.read(playlistPlazaApiClientProvider);
  }
}
