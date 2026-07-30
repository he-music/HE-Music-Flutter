import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/models/he_music_models.dart';
import '../../../../../shared/utils/in_flight_request_cache.dart';
import '../../../../online/domain/entities/online_platform.dart';
import '../../../../online/presentation/providers/online_providers.dart';
import '../../../shared/domain/entities/new_release_tab.dart';
import '../../../shared/domain/entities/new_release_page_result.dart';
import '../../data/datasources/new_song_api_client.dart';
import '../../domain/entities/new_song_page_state.dart';
import '../providers/new_song_page_providers.dart';

class NewSongPageController extends Notifier<NewSongPageState> {
  final InFlightRequestCache<String, List<NewReleaseTab>> _tabRequests =
      InFlightRequestCache<String, List<NewReleaseTab>>();
  final InFlightRequestCache<
    ({String platformId, String tabId, int pageIndex}),
    NewReleasePageResult<SongInfo>
  >
  _pageRequests =
      InFlightRequestCache<
        ({String platformId, String tabId, int pageIndex}),
        NewReleasePageResult<SongInfo>
      >();
  int _requestVersion = 0;

  @override
  NewSongPageState build() {
    return NewSongPageState.initial;
  }

  Future<void> initialize({
    String? preferredPlatformId,
    String? preferredTabId,
  }) async {
    final requestVersion = ++_requestVersion;
    state = state.copyWith(
      tabsLoading: true,
      songsLoading: true,
      loadingMore: false,
      tabs: const [],
      songs: const [],
      hasMore: false,
      pageIndex: 1,
      clearSelectedTab: true,
      clearTabsError: true,
      clearSongsError: true,
    );
    try {
      final platforms = await _loadPlatforms();
      if (requestVersion != _requestVersion) {
        return;
      }
      final platformId = _resolvePlatformId(platforms, preferredPlatformId);
      if (platformId == null) {
        state = state.copyWith(
          platforms: platforms,
          tabsLoading: false,
          songsLoading: false,
        );
        return;
      }
      await _loadPlatform(
        platformId: platformId,
        preferredTabId: preferredTabId,
        availablePlatforms: platforms,
        requestVersion: requestVersion,
      );
    } catch (error) {
      if (requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(
        tabsLoading: false,
        songsLoading: false,
        tabsErrorMessage: '$error',
        songsErrorMessage: '$error',
      );
    }
  }

  Future<void> selectPlatform(String platformId) async {
    final normalizedPlatformId = platformId.trim();
    if (normalizedPlatformId.isEmpty) {
      return;
    }
    final requestVersion = ++_requestVersion;
    await _loadPlatform(
      platformId: normalizedPlatformId,
      requestVersion: requestVersion,
    );
  }

  Future<void> selectTab(String tabId) async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    final normalizedTabId = tabId.trim();
    if (platformId.isEmpty || normalizedTabId.isEmpty) {
      return;
    }
    final requestVersion = ++_requestVersion;
    state = state.copyWith(
      selectedTabId: normalizedTabId,
      songsLoading: true,
      loadingMore: false,
      songs: const [],
      hasMore: false,
      pageIndex: 1,
      clearSongsError: true,
    );
    await _loadFirstPage(
      platformId: platformId,
      tabId: normalizedTabId,
      requestVersion: requestVersion,
    );
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
    final requestVersion = _requestVersion;
    state = state.copyWith(loadingMore: true, clearSongsError: true);
    try {
      final currentPageIndex = state.pageIndex;
      final result = await _pageRequests.run(
        (platformId: platformId, tabId: tabId, pageIndex: currentPageIndex),
        () => _apiClient.fetchSongs(
          platform: platformId,
          tabId: tabId,
          pageIndex: currentPageIndex,
        ),
      );
      if (requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(
        loadingMore: false,
        songs: [...state.songs, ...result.list],
        hasMore: result.hasMore,
        pageIndex: currentPageIndex + 1,
      );
    } catch (error) {
      if (requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(loadingMore: false, songsErrorMessage: '$error');
    }
  }

  Future<void> retry() async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    if (platformId.isEmpty) {
      await initialize();
      return;
    }
    final requestVersion = ++_requestVersion;
    await _loadPlatform(
      platformId: platformId,
      preferredTabId: state.selectedTabId,
      requestVersion: requestVersion,
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
    required int requestVersion,
    String? preferredTabId,
    List<OnlinePlatform>? availablePlatforms,
  }) async {
    if (requestVersion != _requestVersion) {
      return;
    }
    state = state.copyWith(
      selectedPlatformId: platformId,
      tabsLoading: true,
      songsLoading: true,
      loadingMore: false,
      tabs: const [],
      songs: const [],
      hasMore: false,
      pageIndex: 1,
      clearSelectedTab: true,
      clearTabsError: true,
      clearSongsError: true,
    );
    try {
      final platforms = availablePlatforms ?? await _loadPlatforms();
      if (requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(platforms: platforms);
      final tabs = await _tabRequests.run(
        platformId,
        () => _apiClient.fetchTabs(platform: platformId),
      );
      if (requestVersion != _requestVersion) {
        return;
      }
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
      await _loadFirstPage(
        platformId: platformId,
        tabId: selectedTabId,
        requestVersion: requestVersion,
      );
    } catch (error) {
      if (requestVersion != _requestVersion) {
        return;
      }
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
    required int requestVersion,
  }) async {
    try {
      final result = await _pageRequests.run(
        (platformId: platformId, tabId: tabId, pageIndex: 1),
        () => _apiClient.fetchSongs(
          platform: platformId,
          tabId: tabId,
          pageIndex: 1,
        ),
      );
      if (requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(
        songsLoading: false,
        songs: result.list,
        hasMore: result.hasMore,
        pageIndex: 2,
        clearSongsError: true,
      );
    } catch (error) {
      if (requestVersion != _requestVersion) {
        return;
      }
      state = state.copyWith(songsLoading: false, songsErrorMessage: '$error');
    }
  }

  NewSongApiClient get _apiClient {
    return ref.read(newSongApiClientProvider);
  }
}
