import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../online/domain/entities/online_platform.dart';
import '../../../../online/presentation/providers/online_providers.dart';
import '../../../shared/domain/entities/new_release_tab.dart';
import '../../data/datasources/new_song_api_client.dart';
import '../../domain/entities/new_song_page_state.dart';
import '../providers/new_song_page_providers.dart';

class NewSongPageController extends Notifier<NewSongPageState> {
  @override
  NewSongPageState build() {
    return NewSongPageState.initial;
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
      songsLoading: true,
      songs: const [],
      hasMore: false,
      pageIndex: 1,
      clearSongsError: true,
    );
    await _loadFirstPage(platformId: platformId, tabId: normalizedTabId);
  }

  Future<void> loadMore() async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    final tabId = state.selectedTabId?.trim() ?? '';
    if (platformId.isEmpty ||
        tabId.isEmpty ||
        state.loadingMore ||
        state.songsLoading ||
        !state.hasMore) {
      return;
    }
    state = state.copyWith(loadingMore: true, clearSongsError: true);
    try {
      final result = await _apiClient.fetchSongs(
        platform: platformId,
        tabId: tabId,
        pageIndex: state.pageIndex,
      );
      state = state.copyWith(
        loadingMore: false,
        songs: [...state.songs, ...result.list],
        hasMore: result.hasMore,
        pageIndex: state.pageIndex + 1,
      );
    } catch (error) {
      state = state.copyWith(loadingMore: false, songsErrorMessage: '$error');
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
              platform.supports(PlatformFeatureSupportFlag.getNewSongTabList) &&
              platform.supports(PlatformFeatureSupportFlag.getNewSongList),
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
      songsLoading: true,
      tabs: const [],
      selectedTabId: null,
      songs: const [],
      hasMore: false,
      pageIndex: 1,
      clearTabsError: true,
      clearSongsError: true,
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
        state = state.copyWith(songsLoading: false);
        return;
      }
      await _loadFirstPage(platformId: platformId, tabId: selectedTabId);
    } catch (error) {
      state = state.copyWith(
        tabsLoading: false,
        songsLoading: false,
        tabsErrorMessage: '$error',
        songsErrorMessage: '$error',
      );
    }
  }

  Future<void> _loadFirstPage({
    required String platformId,
    required String tabId,
  }) async {
    try {
      final result = await _apiClient.fetchSongs(
        platform: platformId,
        tabId: tabId,
        pageIndex: 1,
      );
      state = state.copyWith(
        songsLoading: false,
        songs: result.list,
        hasMore: result.hasMore,
        pageIndex: 2,
        clearSongsError: true,
      );
    } catch (error) {
      state = state.copyWith(songsLoading: false, songsErrorMessage: '$error');
    }
  }

  NewSongApiClient get _apiClient {
    return ref.read(newSongApiClientProvider);
  }
}
