import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/in_flight_request_cache.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../data/providers/home_page_providers.dart';
import '../../domain/entities/home_page_result.dart';
import '../../domain/entities/home_page_section.dart';
import '../../domain/entities/home_page_state.dart';
import '../providers/home_page_providers.dart';

class HomePageController extends Notifier<HomePageState> {
  final InFlightRequestCache<String, HomePageResult> _requests =
      InFlightRequestCache<String, HomePageResult>();
  final Map<HomePageKind, int> _requestVersions = <HomePageKind, int>{
    HomePageKind.recommend: 0,
    HomePageKind.discover: 0,
  };
  // 首页会话内按页签和平台保留内容快照，切换平台时恢复原分页进度。
  final Map<HomePageKind, Map<String, HomeContentState>> _platformContents =
      <HomePageKind, Map<String, HomeContentState>>{
        HomePageKind.recommend: <String, HomeContentState>{},
        HomePageKind.discover: <String, HomeContentState>{},
      };
  Future<void>? _initializing;
  bool _initialized = false;

  @override
  HomePageState build() {
    ref.listen(onlinePlatformsProvider, (previous, next) {
      final platforms = next.value;
      if (_initialized ||
          _initializing != null ||
          platforms == null ||
          platforms.isEmpty ||
          state.platformErrorMessage == null) {
        return;
      }
      unawaited(initialize());
    });
    return HomePageState.initial;
  }

  Future<void> initialize() {
    if (_initialized) {
      return Future<void>.value();
    }
    final current = _initializing;
    if (current != null) {
      return current;
    }
    final future = _initialize();
    _initializing = future;
    return future;
  }

  Future<void> _initialize() async {
    try {
      final platforms = await _resolvePlatforms();
      state = state.copyWith(platforms: platforms, clearPlatformError: true);
      final availablePages = state.availablePages;
      if (availablePages.isEmpty) {
        throw StateError('No home page platform available');
      }
      final page = availablePages.contains(HomePageKind.recommend)
          ? HomePageKind.recommend
          : availablePages.first;
      final platformId = state.platformsFor(page).first.id;
      state = state.copyWith(selectedPage: page);
      await _loadFirstPage(page, platformId, clearContent: true);
      _initialized = state.platformErrorMessage == null;
    } catch (error) {
      state = state.copyWith(platformErrorMessage: '$error');
    } finally {
      _initializing = null;
    }
  }

  Future<void> retryPlatforms() async {
    _initialized = false;
    state = state.copyWith(clearPlatformError: true);
    await initialize();
  }

  Future<void> selectPage(HomePageKind page) async {
    if (page == state.selectedPage || !state.availablePages.contains(page)) {
      return;
    }
    final source = state.contentFor(state.selectedPage);
    final target = state.contentFor(page);
    final supportedPlatforms = state.platformsFor(page);
    if (supportedPlatforms.isEmpty) {
      return;
    }
    final platformId = _resolveTargetPlatformId(
      sourcePlatformId: source.selectedPlatformId,
      targetPlatformId: target.selectedPlatformId,
      supportedPlatforms: supportedPlatforms,
    );
    state = state.copyWith(selectedPage: page);
    if (target.initialized && target.selectedPlatformId == platformId) {
      return;
    }
    await _selectContentPlatform(page, platformId);
  }

  Future<void> selectPlatform(String platformId) async {
    final normalized = platformId.trim();
    final page = state.selectedPage;
    final content = state.contentFor(page);
    if (normalized.isEmpty ||
        normalized == content.selectedPlatformId ||
        !state
            .platformsFor(page)
            .any((platform) => platform.id == normalized)) {
      return;
    }
    await _selectContentPlatform(page, normalized);
  }

  Future<void> retry() async {
    final page = state.selectedPage;
    final platformId = state.contentFor(page).selectedPlatformId;
    if (platformId == null || platformId.isEmpty) {
      return;
    }
    await _loadFirstPage(page, platformId, clearContent: true);
  }

  Future<String?> refresh() async {
    final page = state.selectedPage;
    final content = state.contentFor(page);
    final platformId = content.selectedPlatformId;
    if (platformId == null ||
        platformId.isEmpty ||
        content.loading ||
        content.refreshing) {
      return null;
    }
    final requestVersion = _nextRequestVersion(page);
    _replaceContent(
      page,
      content.copyWith(
        refreshing: true,
        loadingMore: false,
        clearLoadMoreError: true,
      ),
    );
    try {
      final result = await _fetchPage(page, platformId, 1);
      if (!_canCommit(page, platformId, requestVersion)) {
        return null;
      }
      _replaceContent(
        page,
        state
            .contentFor(page)
            .copyWith(
              initialized: true,
              loading: false,
              refreshing: false,
              loadingMore: false,
              sections: result.sections,
              hasMore: page == HomePageKind.recommend && result.hasMore,
              nextPageIndex: 2,
              clearError: true,
              clearLoadMoreError: true,
            ),
      );
      return null;
    } catch (error) {
      if (!_canCommit(page, platformId, requestVersion)) {
        return null;
      }
      _replaceContent(page, state.contentFor(page).copyWith(refreshing: false));
      return '$error';
    }
  }

  Future<void> loadMore() async {
    const page = HomePageKind.recommend;
    final content = state.contentFor(page);
    final platformId = content.selectedPlatformId;
    if (!content.initialized ||
        content.loading ||
        content.refreshing ||
        content.loadingMore ||
        !content.hasMore ||
        platformId == null ||
        platformId.isEmpty) {
      return;
    }
    final requestVersion = _requestVersions[page] ?? 0;
    final pageIndex = content.nextPageIndex;
    _replaceContent(
      page,
      content.copyWith(loadingMore: true, clearLoadMoreError: true),
    );
    try {
      final result = await _fetchPage(page, platformId, pageIndex);
      if (!_canCommit(page, platformId, requestVersion)) {
        return;
      }
      final latest = state.contentFor(page);
      _replaceContent(
        page,
        latest.copyWith(
          loadingMore: false,
          sections: appendRecommendSections(latest.sections, result.sections),
          hasMore: result.hasMore,
          nextPageIndex: pageIndex + 1,
          clearLoadMoreError: true,
        ),
      );
    } catch (error) {
      if (!_canCommit(page, platformId, requestVersion)) {
        return;
      }
      _replaceContent(
        page,
        state
            .contentFor(page)
            .copyWith(loadingMore: false, loadMoreErrorMessage: '$error'),
      );
    }
  }

  Future<void> _loadFirstPage(
    HomePageKind page,
    String platformId, {
    required bool clearContent,
  }) async {
    final requestVersion = _nextRequestVersion(page);
    final current = state.contentFor(page);
    _replaceContent(
      page,
      current.copyWith(
        initialized: false,
        loading: true,
        refreshing: false,
        loadingMore: false,
        selectedPlatformId: platformId,
        sections: clearContent ? const <HomePageSection>[] : current.sections,
        hasMore: false,
        nextPageIndex: 1,
        clearError: true,
        clearLoadMoreError: true,
      ),
    );
    try {
      final result = await _fetchPage(page, platformId, 1);
      if (!_canCommit(page, platformId, requestVersion)) {
        return;
      }
      _replaceContent(
        page,
        state
            .contentFor(page)
            .copyWith(
              initialized: true,
              loading: false,
              sections: result.sections,
              hasMore: page == HomePageKind.recommend && result.hasMore,
              nextPageIndex: 2,
              clearError: true,
              clearLoadMoreError: true,
            ),
      );
    } catch (error) {
      if (!_canCommit(page, platformId, requestVersion)) {
        return;
      }
      _replaceContent(
        page,
        state
            .contentFor(page)
            .copyWith(
              initialized: true,
              loading: false,
              hasMore: false,
              nextPageIndex: 1,
              errorMessage: '$error',
              clearLoadMoreError: true,
            ),
      );
    }
  }

  Future<void> _selectContentPlatform(
    HomePageKind page,
    String platformId,
  ) async {
    final cached = _platformContents[page]?[platformId];
    if (cached != null && cached.initialized) {
      _nextRequestVersion(page);
      _replaceContent(
        page,
        cached.copyWith(loading: false, refreshing: false, loadingMore: false),
      );
      return;
    }
    await _loadFirstPage(page, platformId, clearContent: true);
  }

  Future<HomePageResult> _fetchPage(
    HomePageKind page,
    String platformId,
    int pageIndex,
  ) {
    final key = '${page.name}|$platformId|$pageIndex';
    return _requests.run(key, () {
      if (page == HomePageKind.recommend) {
        return _apiClient.fetchRecommendPage(
          platformId: platformId,
          pageIndex: pageIndex,
        );
      }
      return _apiClient.fetchDiscoverPage(platformId: platformId);
    });
  }

  String _resolveTargetPlatformId({
    required String? sourcePlatformId,
    required String? targetPlatformId,
    required List<OnlinePlatform> supportedPlatforms,
  }) {
    final source = sourcePlatformId?.trim() ?? '';
    if (supportedPlatforms.any((platform) => platform.id == source)) {
      return source;
    }
    final target = targetPlatformId?.trim() ?? '';
    if (supportedPlatforms.any((platform) => platform.id == target)) {
      return target;
    }
    return supportedPlatforms.first.id;
  }

  int _nextRequestVersion(HomePageKind page) {
    final next = (_requestVersions[page] ?? 0) + 1;
    _requestVersions[page] = next;
    return next;
  }

  bool _canCommit(HomePageKind page, String platformId, int requestVersion) {
    return _requestVersions[page] == requestVersion &&
        state.contentFor(page).selectedPlatformId == platformId;
  }

  void _replaceContent(HomePageKind page, HomeContentState content) {
    final platformId = content.selectedPlatformId?.trim() ?? '';
    if (platformId.isNotEmpty) {
      _platformContents[page]?[platformId] = content;
    }
    state = state.replaceContent(page, content);
  }

  HomePageApiClient get _apiClient => ref.read(homePageApiClientProvider);

  Future<List<OnlinePlatform>> _resolvePlatforms() async {
    final cached = ref.read(onlinePlatformsProvider).value;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return ref.read(onlinePlatformsProvider.notifier).ensureLoaded();
  }
}
