import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/he_music_models.dart';

/// 通用过滤广场分页结果。
class FilterPlazaPageResult<T> {
  const FilterPlazaPageResult({required this.list, required this.hasMore});

  final List<T> list;
  final bool hasMore;
}

/// 通用过滤广场状态。
///
/// [T] 为列表元素类型（如 [ArtistInfo]、[MvInfo]）。
class FilterPlazaState<T> {
  const FilterPlazaState({
    required this.selectedPlatformId,
    required this.filtersLoading,
    required this.itemsLoading,
    required this.loadingMore,
    required this.filterGroups,
    required this.selectedFilters,
    required this.items,
    required this.hasMore,
    required this.pageIndex,
    this.filtersErrorMessage,
    this.itemsErrorMessage,
  });

  final String? selectedPlatformId;
  final bool filtersLoading;
  final bool itemsLoading;
  final bool loadingMore;
  final List<FilterInfo> filterGroups;
  final Map<String, String> selectedFilters;
  final List<T> items;
  final bool hasMore;
  final int pageIndex;
  final String? filtersErrorMessage;
  final String? itemsErrorMessage;

  FilterPlazaState<T> copyWith({
    String? selectedPlatformId,
    bool? filtersLoading,
    bool? itemsLoading,
    bool? loadingMore,
    List<FilterInfo>? filterGroups,
    Map<String, String>? selectedFilters,
    List<T>? items,
    bool? hasMore,
    int? pageIndex,
    String? filtersErrorMessage,
    String? itemsErrorMessage,
    bool clearFiltersError = false,
    bool clearItemsError = false,
  }) {
    return FilterPlazaState<T>(
      selectedPlatformId: selectedPlatformId ?? this.selectedPlatformId,
      filtersLoading: filtersLoading ?? this.filtersLoading,
      itemsLoading: itemsLoading ?? this.itemsLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      filterGroups: filterGroups ?? this.filterGroups,
      selectedFilters: selectedFilters ?? this.selectedFilters,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      pageIndex: pageIndex ?? this.pageIndex,
      filtersErrorMessage: clearFiltersError
          ? null
          : filtersErrorMessage ?? this.filtersErrorMessage,
      itemsErrorMessage: clearItemsError
          ? null
          : itemsErrorMessage ?? this.itemsErrorMessage,
    );
  }

  static FilterPlazaState<T> initial<T>() {
    return FilterPlazaState<T>(
      selectedPlatformId: null,
      filtersLoading: false,
      itemsLoading: false,
      loadingMore: false,
      filterGroups: const <FilterInfo>[],
      selectedFilters: const <String, String>{},
      items: const [],
      hasMore: false,
      pageIndex: 1,
    );
  }
}

/// 通用过滤广场控制器基类。
///
/// 子类只需实现 [fetchFilters] 和 [fetchContent] 两个抽象方法。
/// 提供完整的平台切换、过滤器选择、分页加载、重试和缓存逻辑。
abstract class FilterPlazaController<T> extends Notifier<FilterPlazaState<T>> {
  final Map<String, List<FilterInfo>> _filterCache =
      <String, List<FilterInfo>>{};
  final Map<String, Map<String, String>> _selectedFilterCache =
      <String, Map<String, String>>{};

  @override
  FilterPlazaState<T> build() {
    return FilterPlazaState.initial<T>();
  }

  /// 从 API 获取过滤器组。
  Future<List<FilterInfo>> fetchFilters(String platform);

  /// 从 API 获取分页内容。
  Future<FilterPlazaPageResult<T>> fetchContent({
    required String platform,
    required Map<String, String> filters,
    required int pageIndex,
  });

  Future<void> initialize(String platformId) async {
    final currentPlatform = state.selectedPlatformId?.trim() ?? '';
    if (currentPlatform == platformId.trim() && state.filterGroups.isNotEmpty) {
      return;
    }
    await selectPlatform(platformId);
  }

  Future<void> selectPlatform(String platformId) async {
    final normalizedPlatformId = platformId.trim();
    if (normalizedPlatformId.isEmpty) {
      return;
    }
    state = state.copyWith(
      selectedPlatformId: normalizedPlatformId,
      filtersLoading: true,
      itemsLoading: true,
      filterGroups: const <FilterInfo>[],
      selectedFilters: const <String, String>{},
      items: <T>[],
      hasMore: false,
      pageIndex: 1,
      clearFiltersError: true,
      clearItemsError: true,
    );
    try {
      final filterGroups = await _loadFilters(normalizedPlatformId);
      final selectedFilters = _resolveSelectedFilters(
        platformId: normalizedPlatformId,
        filterGroups: filterGroups,
      );
      _selectedFilterCache[normalizedPlatformId] = selectedFilters;
      state = state.copyWith(
        filtersLoading: false,
        filterGroups: filterGroups,
        selectedFilters: selectedFilters,
      );
      await _loadFirstPage(
        platformId: normalizedPlatformId,
        selectedFilters: selectedFilters,
      );
    } catch (error) {
      state = state.copyWith(
        filtersLoading: false,
        itemsLoading: false,
        filtersErrorMessage: '$error',
        itemsErrorMessage: '$error',
      );
    }
  }

  Future<void> selectFilter({
    required String groupId,
    required String value,
  }) async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    final normalizedGroupId = groupId.trim();
    final normalizedValue = value.trim();
    if (platformId.isEmpty || normalizedGroupId.isEmpty) {
      return;
    }
    if (state.selectedFilters[normalizedGroupId] == normalizedValue &&
        state.items.isNotEmpty) {
      return;
    }
    final nextFilters = <String, String>{
      ...state.selectedFilters,
      normalizedGroupId: normalizedValue,
    };
    _selectedFilterCache[platformId] = nextFilters;
    state = state.copyWith(
      selectedFilters: nextFilters,
      itemsLoading: true,
      items: <T>[],
      hasMore: false,
      pageIndex: 1,
      clearItemsError: true,
    );
    try {
      await _loadFirstPage(
        platformId: platformId,
        selectedFilters: nextFilters,
      );
    } catch (error) {
      state = state.copyWith(itemsLoading: false, itemsErrorMessage: '$error');
    }
  }

  Future<void> retry() async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    if (platformId.isEmpty) {
      return;
    }
    if (state.filterGroups.isEmpty || state.filtersErrorMessage != null) {
      await selectPlatform(platformId);
      return;
    }
    state = state.copyWith(
      itemsLoading: true,
      items: <T>[],
      hasMore: false,
      pageIndex: 1,
      clearItemsError: true,
    );
    try {
      await _loadFirstPage(
        platformId: platformId,
        selectedFilters: state.selectedFilters,
      );
    } catch (error) {
      state = state.copyWith(itemsLoading: false, itemsErrorMessage: '$error');
    }
  }

  Future<void> loadMore() async {
    final platformId = state.selectedPlatformId?.trim() ?? '';
    if (platformId.isEmpty ||
        state.loadingMore ||
        state.itemsLoading ||
        !state.hasMore) {
      return;
    }
    state = state.copyWith(loadingMore: true, clearItemsError: true);
    try {
      final currentPageIndex = state.pageIndex;
      final currentItems = state.items;
      final result = await fetchContent(
        platform: platformId,
        filters: state.selectedFilters,
        pageIndex: currentPageIndex,
      );
      state = state.copyWith(
        loadingMore: false,
        items: <T>[...currentItems, ...result.list],
        hasMore: result.hasMore,
        pageIndex: currentPageIndex + 1,
      );
    } catch (error) {
      state = state.copyWith(loadingMore: false, itemsErrorMessage: '$error');
    }
  }

  Future<List<FilterInfo>> _loadFilters(String platformId) async {
    final cached = _filterCache[platformId];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final groups = await fetchFilters(platformId);
    _filterCache[platformId] = groups;
    return groups;
  }

  Map<String, String> _resolveSelectedFilters({
    required String platformId,
    required List<FilterInfo> filterGroups,
  }) {
    final cached = _selectedFilterCache[platformId] ?? const <String, String>{};
    final result = <String, String>{};
    for (final group in filterGroups) {
      final groupId = group.id.trim();
      if (groupId.isEmpty || group.options.isEmpty) {
        continue;
      }
      final cachedValue = cached[groupId]?.trim() ?? '';
      final matched = group.options.any(
        (option) => option.value.trim() == cachedValue,
      );
      result[groupId] = matched ? cachedValue : group.options.first.value;
    }
    return result;
  }

  Future<void> _loadFirstPage({
    required String platformId,
    required Map<String, String> selectedFilters,
  }) async {
    final result = await fetchContent(
      platform: platformId,
      filters: selectedFilters,
      pageIndex: 1,
    );
    state = state.copyWith(
      itemsLoading: false,
      items: result.list,
      hasMore: result.hasMore,
      pageIndex: 2,
      clearItemsError: true,
    );
  }
}
