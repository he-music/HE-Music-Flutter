import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../online/domain/entities/online_platform.dart';
import '../../../../online/presentation/providers/online_providers.dart';
import '../../../shared/domain/entities/new_release_tab.dart';
import '../../data/datasources/new_album_api_client.dart';
import '../../domain/entities/new_album_page_state.dart';
import '../providers/new_album_page_providers.dart';

class NewAlbumPageController extends Notifier<NewAlbumPageState> {
  @override
  NewAlbumPageState build() {
    return NewAlbumPageState.initial;
  }

  Future<void> initialize({
    String? preferredPlatformId,
    String? preferredTabId,
  }) async {
    final platforms = await _loadPlatforms();
    final platformId = _resolvePlatformId(platforms, preferredPlatformId);
    if (platformId == null) {
      state = state.copyWith(platforms: platforms);
      return;
    }
    await _loadPlatform(platformId: platformId, preferredTabId: preferredTabId);
  }

  Future<void> selectPlatform(String platformId) async {
    await _loadPlatform(platformId: platformId);
  }

  Future<void> selectTab(String tabId) async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    final normalizedTabId = tabId.trim();
    if (platformId.isEmpty || normalizedTabId.isEmpty) {
      return;
    }
    state = state.copyWith(
      selectedTabId: normalizedTabId,
      albumsLoading: true,
      albums: const [],
      hasMore: false,
      pageIndex: 1,
      clearAlbumsError: true,
    );
    await _loadFirstPage(platformId: platformId, tabId: normalizedTabId);
  }

  Future<void> loadMore() async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    final tabId = state.selectedTabId?.trim() ?? '';
    if (platformId.isEmpty ||
        tabId.isEmpty ||
        state.loadingMore ||
        state.albumsLoading ||
        !state.hasMore) {
      return;
    }
    state = state.copyWith(loadingMore: true, clearAlbumsError: true);
    try {
      final result = await _apiClient.fetchAlbums(
        platform: platformId,
        tabId: tabId,
        pageIndex: state.pageIndex,
      );
      state = state.copyWith(
        loadingMore: false,
        albums: [...state.albums, ...result.list],
        hasMore: result.hasMore,
        pageIndex: state.pageIndex + 1,
      );
    } catch (error) {
      state = state.copyWith(loadingMore: false, albumsErrorMessage: '$error');
    }
  }

  Future<void> retry() async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    if (platformId.isEmpty) {
      await initialize();
      return;
    }
    await _loadPlatform(
      platformId: platformId,
      preferredTabId: state.selectedTabId,
    );
  }

  Future<List<OnlinePlatform>> _loadPlatforms() async {
    final platforms = await ref.read(onlinePlatformsProvider.future);
    return platforms
        .where(
          (platform) =>
              platform.available &&
              platform.supports(
                PlatformFeatureSupportFlag.getNewAlbumTabList,
              ) &&
              platform.supports(PlatformFeatureSupportFlag.getNewAlbumList),
        )
        .toList(growable: false);
  }

  String? _resolvePlatformId(
    List<OnlinePlatform> platforms,
    String? preferredPlatformId,
  ) {
    final normalizedPreferred = preferredPlatformId?.trim() ?? '';
    if (normalizedPreferred.isNotEmpty) {
      for (final platform in platforms) {
        if (platform.id == normalizedPreferred) {
          return platform.id;
        }
      }
    }
    if (platforms.isEmpty) {
      return null;
    }
    return platforms.first.id;
  }

  String? _resolveTabId(List<NewReleaseTab> tabs, String? preferredTabId) {
    final normalizedPreferred = preferredTabId?.trim() ?? '';
    if (normalizedPreferred.isNotEmpty) {
      for (final tab in tabs) {
        if (tab.id == normalizedPreferred) {
          return tab.id;
        }
      }
    }
    if (tabs.isEmpty) {
      return null;
    }
    return tabs.first.id;
  }

  Future<void> _loadPlatform({
    required String platformId,
    String? preferredTabId,
  }) async {
    final platforms = await _loadPlatforms();
    state = state.copyWith(
      platforms: platforms,
      selectedPlatformId: platformId,
      tabsLoading: true,
      albumsLoading: true,
      tabs: const [],
      selectedTabId: null,
      albums: const [],
      hasMore: false,
      pageIndex: 1,
      clearTabsError: true,
      clearAlbumsError: true,
    );
    try {
      final tabs = await _apiClient.fetchTabs(platform: platformId);
      final selectedTabId = _resolveTabId(tabs, preferredTabId);
      state = state.copyWith(
        tabsLoading: false,
        tabs: tabs,
        selectedTabId: selectedTabId,
      );
      if (selectedTabId == null) {
        state = state.copyWith(albumsLoading: false);
        return;
      }
      await _loadFirstPage(platformId: platformId, tabId: selectedTabId);
    } catch (error) {
      state = state.copyWith(
        tabsLoading: false,
        albumsLoading: false,
        tabsErrorMessage: '$error',
        albumsErrorMessage: '$error',
      );
    }
  }

  Future<void> _loadFirstPage({
    required String platformId,
    required String tabId,
  }) async {
    try {
      final result = await _apiClient.fetchAlbums(
        platform: platformId,
        tabId: tabId,
        pageIndex: 1,
      );
      state = state.copyWith(
        albumsLoading: false,
        albums: result.list,
        hasMore: result.hasMore,
        pageIndex: 2,
        clearAlbumsError: true,
      );
    } catch (error) {
      state = state.copyWith(
        albumsLoading: false,
        albumsErrorMessage: '$error',
      );
    }
  }

  NewAlbumApiClient get _apiClient {
    return ref.read(newAlbumApiClientProvider);
  }
}
